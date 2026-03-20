defmodule Boon.Printing.Dispatcher do
  @moduledoc """
  Coordinates print payload generation, dispatch, and `PrintJob` persistence.
  """

  alias Boon.Operations

  alias Boon.Printing.{
    LabelBatch,
    LabelTransport,
    LabelZpl,
    PalletTagBatch,
    PalletTagPdf,
    PalletTagTransport
  }

  alias Boon.ShippingLocation

  @label_document_type "labels"
  @pallet_tag_document_type "pallet_tags"

  @spec dispatch_work_package(map, keyword) :: {:ok, map}
  def dispatch_work_package(work_package, opts \\ []) do
    label_result = dispatch_labels(work_package, opts)

    pallet_tag_results =
      Enum.map(work_package.purchase_orders, fn purchase_order ->
        dispatch_pallet_tags_for_purchase_order(work_package, purchase_order, opts)
      end)

    errors =
      [label_result | pallet_tag_results]
      |> Enum.flat_map(fn result ->
        case result do
          %{error: nil} -> []
          %{error: error} when is_binary(error) -> [error]
          _ -> []
        end
      end)

    {:ok,
     %{
       label_job: label_result,
       pallet_tag_jobs: pallet_tag_results,
       errors: errors
     }}
  end

  defp dispatch_labels(work_package, opts) do
    labels = LabelBatch.derive_work_package(work_package)

    if labels == [] do
      %{
        document_type: @label_document_type,
        status: :skipped,
        target_printer: ShippingLocation.shared_label_printer(),
        error: nil,
        payload_path: nil,
        print_job: nil
      }
    else
      printer = resolve_label_printer(work_package)

      case printer do
        nil ->
          create_failed_result(
            @label_document_type,
            nil,
            work_package.id,
            nil,
            nil,
            "No shared label printer is configured for this work package."
          )

        printer_name ->
          zpl = LabelZpl.render_batch(labels)

          payload_path =
            build_payload_path(opts, "labels", work_package.number, ".zpl")

          transport = Keyword.get(opts, :label_transport, LabelTransport)
          transport_opts = Keyword.get(opts, :label_transport_opts, [])

          run_print_job(
            @label_document_type,
            printer_name,
            work_package.id,
            nil,
            payload_path,
            fn -> File.write(payload_path, zpl) end,
            fn -> transport.print(printer_name, zpl, transport_opts) end
          )
      end
    end
  end

  defp dispatch_pallet_tags_for_purchase_order(work_package, purchase_order, opts) do
    printer_name = ShippingLocation.pallet_tag_printer(purchase_order.ship_to)

    case PalletTagBatch.derive_purchase_order(purchase_order, work_package.number) do
      {:ok, tags} ->
        case printer_name do
          nil ->
            create_failed_result(
              @pallet_tag_document_type,
              nil,
              work_package.id,
              purchase_order.id,
              nil,
              "No pallet-tag printer is configured for ship-to #{purchase_order.ship_to || "unknown"}."
            )

          printer ->
            payload_path =
              build_payload_path(opts, purchase_order.po_number, work_package.number, ".pdf")

            transport = Keyword.get(opts, :pallet_tag_transport, PalletTagTransport)
            transport_opts = Keyword.get(opts, :pallet_tag_transport_opts, [])

            run_print_job(
              @pallet_tag_document_type,
              printer,
              work_package.id,
              purchase_order.id,
              payload_path,
              fn -> PalletTagPdf.write(tags, payload_path) end,
              fn -> transport.print(printer, payload_path, transport_opts) end
            )
        end

      {:error, error} ->
        create_failed_result(
          @pallet_tag_document_type,
          printer_name,
          work_package.id,
          purchase_order.id,
          nil,
          error
        )
    end
  end

  defp run_print_job(
         document_type,
         printer_name,
         work_package_id,
         purchase_order_id,
         payload_path,
         write_fun,
         print_fun
       ) do
    case Operations.create_print_job(%{
           document_type: document_type,
           target_printer: printer_name,
           status: "pending",
           payload_path: payload_path,
           work_package_id: work_package_id,
           purchase_order_id: purchase_order_id
         }) do
      {:ok, print_job} ->
        case write_fun.() do
          :ok ->
            case print_fun.() do
              :ok ->
                case update_print_job(print_job, %{status: "completed", error_details: nil}) do
                  {:ok, completed_job} ->
                    %{
                      document_type: document_type,
                      status: :completed,
                      target_printer: printer_name,
                      error: nil,
                      payload_path: payload_path,
                      print_job: completed_job
                    }

                  {:error, error} ->
                    failed_result(
                      print_job,
                      document_type,
                      printer_name,
                      payload_path,
                      format_error(error)
                    )
                end

              {:error, error} when is_binary(error) ->
                failed_result(print_job, document_type, printer_name, payload_path, error)

              {:error, error} ->
                failed_result(
                  print_job,
                  document_type,
                  printer_name,
                  payload_path,
                  format_error(error)
                )
            end

          {:error, error} when is_binary(error) ->
            failed_result(print_job, document_type, printer_name, payload_path, error)

          {:error, error} ->
            failed_result(
              print_job,
              document_type,
              printer_name,
              payload_path,
              format_error(error)
            )
        end

      {:error, error} when is_binary(error) ->
        create_failed_result(
          document_type,
          printer_name,
          work_package_id,
          purchase_order_id,
          payload_path,
          error
        )

      {:error, error} ->
        create_failed_result(
          document_type,
          printer_name,
          work_package_id,
          purchase_order_id,
          payload_path,
          format_error(error)
        )
    end
  end

  defp create_failed_result(
         document_type,
         printer_name,
         work_package_id,
         purchase_order_id,
         payload_path,
         error
       ) do
    result = %{
      document_type: document_type,
      status: :failed,
      target_printer: printer_name,
      error: error,
      payload_path: payload_path,
      print_job: nil
    }

    case Operations.create_print_job(%{
           document_type: document_type,
           target_printer: printer_name || "unresolved",
           status: "failed",
           error_details: error,
           payload_path: payload_path,
           work_package_id: work_package_id,
           purchase_order_id: purchase_order_id
         }) do
      {:ok, print_job} -> %{result | print_job: print_job}
      {:error, _create_error} -> result
    end
  end

  defp update_print_job(print_job, attrs) do
    print_job
    |> Ash.Changeset.for_update(:update, attrs)
    |> Ash.update()
  end

  defp failed_result(print_job, document_type, printer_name, payload_path, error) do
    case update_print_job(print_job, %{status: "failed", error_details: error}) do
      {:ok, failed_job} ->
        %{
          document_type: document_type,
          status: :failed,
          target_printer: printer_name,
          error: error,
          payload_path: payload_path,
          print_job: failed_job
        }

      {:error, _update_error} ->
        %{
          document_type: document_type,
          status: :failed,
          target_printer: printer_name,
          error: error,
          payload_path: payload_path,
          print_job: print_job
        }
    end
  end

  defp resolve_label_printer(work_package) do
    work_package.purchase_orders
    |> Enum.find_value(&ShippingLocation.label_printer(&1.ship_to))
    |> case do
      nil -> ShippingLocation.shared_label_printer()
      printer -> printer
    end
  end

  defp build_payload_path(opts, prefix, suffix, extension) do
    temp_dir = Keyword.get(opts, :temp_dir, System.tmp_dir!())
    timestamp = System.system_time(:microsecond)

    filename =
      sanitize_filename(prefix) <>
        "-" <> sanitize_filename(suffix) <> "-" <> Integer.to_string(timestamp) <> extension

    Path.join(temp_dir, filename)
  end

  defp sanitize_filename(value) do
    value
    |> to_string()
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
    |> case do
      "" -> "print-job"
      sanitized -> sanitized
    end
  end

  defp format_error(%_{} = error), do: Exception.message(error)
  defp format_error(error), do: inspect(error)
end
