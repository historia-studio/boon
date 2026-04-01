defmodule Boon.Printing.Dispatcher do
  @moduledoc """
  Coordinates print payload generation, dispatch, and `PrintJob` persistence.
  """

  alias Boon.Operations
  alias Boon.Operations.Shipment

  alias Boon.Printing.{
    LabelBatch,
    LabelTransport,
    PackingSlip,
    PackingSlipPdf,
    LabelZpl,
    PalletTagBatch,
    PalletTagPdf,
    PalletTagTransport
  }

  alias Boon.Shipping.URL
  alias Boon.ShippingLocation

  @label_document_type "labels"
  @pallet_tag_document_type "pallet_tags"
  @packing_slip_document_type "packing_slip"

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

  @spec dispatch_work_package_labels(map, keyword) :: {:ok, map}
  def dispatch_work_package_labels(work_package, opts \\ []) do
    labels = LabelBatch.derive_work_package(work_package)

    {:ok,
     dispatch_label_batch(
       labels,
       resolve_label_printer(work_package),
       work_package.id,
       nil,
       ["labels", work_package.number],
       "Work package #{work_package.number} does not contain any label-eligible lines.",
       opts
     )}
  end

  @spec dispatch_purchase_order_labels(map, map, keyword) :: {:ok, map}
  def dispatch_purchase_order_labels(work_package, purchase_order, opts \\ []) do
    labels = LabelBatch.derive_purchase_order(purchase_order, work_package.number)

    {:ok,
     dispatch_label_batch(
       labels,
       ShippingLocation.label_printer(purchase_order.ship_to) ||
         resolve_label_printer(work_package),
       work_package.id,
       purchase_order.id,
       ["labels", work_package.number, purchase_order.po_number],
       "PO #{purchase_order.po_number} does not contain any label-eligible lines.",
       opts
     )}
  end

  @spec dispatch_purchase_order_line_labels(map, map, map, keyword) :: {:ok, map}
  def dispatch_purchase_order_line_labels(work_package, purchase_order, line, opts \\ []) do
    labels = LabelBatch.derive_purchase_order_line(line, purchase_order, work_package.number)

    {:ok,
     dispatch_label_batch(
       labels,
       ShippingLocation.label_printer(purchase_order.ship_to) ||
         resolve_label_printer(work_package),
       work_package.id,
       purchase_order.id,
       ["labels", work_package.number, purchase_order.po_number, line.line],
       "PO #{purchase_order.po_number} line #{line.line} does not require printed labels.",
       opts
     )}
  end

  @spec dispatch_work_package_pallet_tags(map, keyword) :: {:ok, map}
  def dispatch_work_package_pallet_tags(work_package, opts \\ []) do
    results =
      Enum.map(work_package.purchase_orders, fn purchase_order ->
        dispatch_pallet_tags_for_purchase_order(work_package, purchase_order, opts)
      end)

    {:ok, summarize_pallet_tag_results(results)}
  end

  @spec dispatch_purchase_order_pallet_tags(map, map, keyword) :: {:ok, map}
  def dispatch_purchase_order_pallet_tags(work_package, purchase_order, opts \\ []) do
    {:ok, dispatch_pallet_tags_for_purchase_order(work_package, purchase_order, opts)}
  end

  @spec dispatch_shipment_packing_slip(map, keyword) :: {:ok, map}
  def dispatch_shipment_packing_slip(shipment, opts \\ []) do
    shipment = Ash.load!(shipment, [:work_package, entries: :purchase_order])
    shipment_index = shipment_sequence_number(shipment)

    result =
      case PackingSlip.build(shipment, shipment_index) do
        {:ok, packing_slip} ->
          dispatch_packing_slip(shipment, packing_slip, shipment_index, opts)

        {:error, error} ->
          create_failed_result(
            @packing_slip_document_type,
            nil,
            shipment.work_package_id,
            nil,
            nil,
            error,
            shipment.entry_count
          )
      end

    {:ok, result}
  end

  defp dispatch_labels(work_package, opts) do
    {:ok, result} = dispatch_work_package_labels(work_package, opts)
    result
  end

  defp dispatch_packing_slip(shipment, packing_slip, shipment_index, opts) do
    printer_name = ShippingLocation.pallet_tag_printer(packing_slip.ship_to)

    case printer_name do
      nil ->
        create_failed_result(
          @packing_slip_document_type,
          nil,
          shipment.work_package_id,
          nil,
          nil,
          "No packing-slip printer is configured for ship-to #{packing_slip.ship_to || "unknown"}.",
          shipment.entry_count
        )

      printer ->
        payload_path =
          build_payload_path(
            opts,
            ["packing-slip", shipment.work_package.number, shipment_index],
            ".pdf"
          )

        transport = Keyword.get(opts, :packing_slip_transport, PalletTagTransport)
        transport_opts = Keyword.get(opts, :packing_slip_transport_opts, [])

        run_print_job(
          @packing_slip_document_type,
          printer,
          shipment.work_package_id,
          nil,
          payload_path,
          fn -> PackingSlipPdf.write(packing_slip, payload_path) end,
          fn -> transport.print(printer, payload_path, transport_opts) end,
          shipment.entry_count
        )
    end
  end

  defp dispatch_label_batch(
         labels,
         printer_name,
         work_package_id,
         purchase_order_id,
         payload_parts,
         empty_message,
         opts
       ) do
    if labels == [] do
      %{
        document_type: @label_document_type,
        status: :skipped,
        target_printer: printer_name,
        error: empty_message,
        payload_path: nil,
        print_job: nil,
        label_count: 0
      }
    else
      case printer_name do
        nil ->
          create_failed_result(
            @label_document_type,
            nil,
            work_package_id,
            purchase_order_id,
            nil,
            "No label printer is configured for this scope.",
            length(labels)
          )

        resolved_printer_name ->
          zpl = LabelZpl.render_batch(labels)
          payload_path = build_payload_path(opts, payload_parts, ".zpl")
          transport = Keyword.get(opts, :label_transport, LabelTransport)
          transport_opts = Keyword.get(opts, :label_transport_opts, [])

          run_print_job(
            @label_document_type,
            resolved_printer_name,
            work_package_id,
            purchase_order_id,
            payload_path,
            fn -> File.write(payload_path, zpl) end,
            fn -> transport.print(resolved_printer_name, zpl, transport_opts) end,
            length(labels)
          )
      end
    end
  end

  defp dispatch_pallet_tags_for_purchase_order(work_package, purchase_order, opts) do
    printer_name = ShippingLocation.pallet_tag_printer(purchase_order.ship_to)

    case PalletTagBatch.derive_purchase_order(purchase_order, work_package.number) do
      {:ok, tags} ->
        tags = enrich_pallet_tags(tags, work_package, purchase_order)

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
              build_payload_path(opts, [purchase_order.po_number, work_package.number], ".pdf")

            transport = Keyword.get(opts, :pallet_tag_transport, PalletTagTransport)
            transport_opts = Keyword.get(opts, :pallet_tag_transport_opts, [])

            run_print_job(
              @pallet_tag_document_type,
              printer,
              work_package.id,
              purchase_order.id,
              payload_path,
              fn -> PalletTagPdf.write(tags, payload_path) end,
              fn -> transport.print(printer, payload_path, transport_opts) end,
              length(tags)
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
         print_fun,
         item_count
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
                      print_job: completed_job,
                      label_count: item_count
                    }

                  {:error, error} ->
                    failed_result(
                      print_job,
                      document_type,
                      printer_name,
                      payload_path,
                      format_error(error),
                      item_count
                    )
                end

              {:error, error} when is_binary(error) ->
                failed_result(
                  print_job,
                  document_type,
                  printer_name,
                  payload_path,
                  error,
                  item_count
                )

              {:error, error} ->
                failed_result(
                  print_job,
                  document_type,
                  printer_name,
                  payload_path,
                  format_error(error),
                  item_count
                )
            end

          {:error, error} when is_binary(error) ->
            failed_result(print_job, document_type, printer_name, payload_path, error, item_count)

          {:error, error} ->
            failed_result(
              print_job,
              document_type,
              printer_name,
              payload_path,
              format_error(error),
              item_count
            )
        end

      {:error, error} when is_binary(error) ->
        create_failed_result(
          document_type,
          printer_name,
          work_package_id,
          purchase_order_id,
          payload_path,
          error,
          item_count
        )

      {:error, error} ->
        create_failed_result(
          document_type,
          printer_name,
          work_package_id,
          purchase_order_id,
          payload_path,
          format_error(error),
          item_count
        )
    end
  end

  defp create_failed_result(
         document_type,
         printer_name,
         work_package_id,
         purchase_order_id,
         payload_path,
         error,
         item_count \\ nil
       ) do
    result = %{
      document_type: document_type,
      status: :failed,
      target_printer: printer_name,
      error: error,
      payload_path: payload_path,
      print_job: nil,
      label_count: item_count
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

  defp failed_result(print_job, document_type, printer_name, payload_path, error, item_count) do
    case update_print_job(print_job, %{status: "failed", error_details: error}) do
      {:ok, failed_job} ->
        %{
          document_type: document_type,
          status: :failed,
          target_printer: printer_name,
          error: error,
          payload_path: payload_path,
          print_job: failed_job,
          label_count: item_count
        }

      {:error, _update_error} ->
        %{
          document_type: document_type,
          status: :failed,
          target_printer: printer_name,
          error: error,
          payload_path: payload_path,
          print_job: print_job,
          label_count: item_count
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

  defp summarize_pallet_tag_results(results) do
    errors =
      results
      |> Enum.flat_map(fn result ->
        case result do
          %{error: error} when is_binary(error) -> [error]
          _ -> []
        end
      end)

    target_printer =
      results
      |> Enum.map(& &1.target_printer)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()
      |> Enum.join(", ")
      |> case do
        "" -> nil
        value -> value
      end

    tag_count =
      results
      |> Enum.map(&(&1.label_count || 0))
      |> Enum.sum()

    status =
      cond do
        errors != [] -> :failed
        tag_count > 0 -> :completed
        true -> :skipped
      end

    %{
      document_type: @pallet_tag_document_type,
      status: status,
      target_printer: target_printer,
      error: if(errors == [], do: nil, else: Enum.join(errors, " ")),
      payload_path: nil,
      print_job: nil,
      print_jobs: results,
      label_count: tag_count
    }
  end

  defp enrich_pallet_tags(tags, work_package, purchase_order) do
    Enum.map(tags, fn tag ->
      Map.merge(tag, %{
        work_package_id: work_package.id,
        purchase_order_id: purchase_order.id,
        shipping_url:
          URL.pallet_tag_url(
            work_package.id,
            purchase_order.id,
            tag.pair_number,
            tag.pallet_type
          )
      })
    end)
  end

  defp shipment_sequence_number(shipment) do
    shipment
    |> shipments_for_work_package()
    |> Enum.sort_by(&shipment_sort_key/1)
    |> Enum.find_index(&(&1.id == shipment.id))
    |> case do
      nil -> 1
      index -> index + 1
    end
  end

  defp shipments_for_work_package(shipment) do
    Shipment
    |> Ash.read!()
    |> Enum.filter(&(&1.work_package_id == shipment.work_package_id))
  end

  defp shipment_sort_key(shipment) do
    {timestamp_value(shipment.confirmed_at), timestamp_value(shipment.inserted_at), shipment.id}
  end

  defp timestamp_value(%DateTime{} = datetime), do: DateTime.to_unix(datetime, :microsecond)
  defp timestamp_value(_other), do: 0

  defp build_payload_path(opts, parts, extension) when is_list(parts) do
    temp_dir = Keyword.get(opts, :temp_dir, System.tmp_dir!())
    timestamp = System.system_time(:microsecond)

    filename =
      (parts
       |> Enum.map(&sanitize_filename/1)
       |> Enum.join("-")) <> "-" <> Integer.to_string(timestamp) <> extension

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

  defp format_error(%{__exception__: true} = error), do: Exception.message(error)

  defp format_error(%{errors: errors}) when is_list(errors) do
    errors
    |> Enum.map(&format_error/1)
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join("; ")
  end

  defp format_error(%{error: error}), do: format_error(error)
  defp format_error(error), do: inspect(error)
end
