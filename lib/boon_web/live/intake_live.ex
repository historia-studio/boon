defmodule BoonWeb.IntakeLive do
  use BoonWeb, :live_view

  alias Boon.Operations
  alias Boon.PDF.UploadImporter
  alias Boon.ShippingLocation

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> allow_upload(:purchase_order_pdf, accept: ~w(.pdf .zip), max_entries: 20)
     |> assign(:collapsed_purchase_orders, MapSet.new())
     |> assign(:current_scope, nil)
     |> assign(:entry, empty_entry())
     |> assign(:form, to_form(%{}, as: :work_package))
     |> assign(:import_form, to_form(%{}, as: :pdf_import))
     |> assign(:import_errors, [])
     |> assign(:import_warnings, [])
     |> assign(:save_errors, [])}
  end

  @impl true
  def handle_event("change", %{"work_package" => params}, socket) do
    {:noreply,
     socket
     |> assign(:entry, normalize_entry(params))
     |> assign(:import_errors, [])
     |> assign(:save_errors, [])}
  end

  @impl true
  def handle_event("queue_import_pdf", _params, socket) do
    {:noreply,
     socket
     |> assign(:import_errors, [])
     |> assign(:import_warnings, [])}
  end

  @impl true
  def handle_event("import_pdf", _params, socket) do
    cond do
      socket.assigns.uploads.purchase_order_pdf.entries == [] ->
        {:noreply,
         socket
         |> assign(:import_errors, ["Select one or more PDF or ZIP files before starting import."])
         |> assign(:import_warnings, [])}

      upload_errors?(socket.assigns.uploads.purchase_order_pdf) ->
        {:noreply,
         socket
         |> assign(
           :import_errors,
           upload_error_messages(socket.assigns.uploads.purchase_order_pdf)
         )
         |> assign(:import_warnings, [])}

      true ->
        result =
          socket
          |> consume_uploaded_entries(:purchase_order_pdf, fn %{path: path}, entry ->
            {:ok, UploadImporter.import_upload(path, entry.client_name)}
          end)
          |> merge_import_results()

        cond do
          result.purchase_orders != [] ->
            {:noreply,
             socket
             |> assign(:collapsed_purchase_orders, MapSet.new())
             |> assign(:entry, import_entry(socket.assigns.entry, result))
             |> assign(:import_errors, result.errors)
             |> assign(:import_warnings, result.warnings)
             |> assign(:save_errors, [])}

          result.errors != [] ->
            {:noreply,
             socket
             |> assign(:import_errors, result.errors)
             |> assign(:import_warnings, [])}

          true ->
            {:noreply,
             socket
             |> assign(:import_errors, ["The uploaded files did not produce any import data."])
             |> assign(:import_warnings, [])}
        end
    end
  end

  @impl true
  def handle_event("add_purchase_order", _params, socket) do
    entry =
      update_in(socket.assigns.entry["purchase_orders"], &(&1 ++ [empty_purchase_order()]))
      |> then(&put_in(socket.assigns.entry["purchase_orders"], &1))

    {:noreply,
     socket
     |> assign(:entry, entry)
     |> assign(:collapsed_purchase_orders, socket.assigns.collapsed_purchase_orders)}
  end

  @impl true
  def handle_event("remove_purchase_order", %{"index" => index}, socket) do
    purchase_orders = remove_at(socket.assigns.entry["purchase_orders"], index)

    entry =
      if purchase_orders == [] do
        put_in(socket.assigns.entry["purchase_orders"], [empty_purchase_order()])
      else
        put_in(socket.assigns.entry["purchase_orders"], purchase_orders)
      end

    {:noreply,
     socket
     |> assign(:entry, entry)
     |> assign(
       :collapsed_purchase_orders,
       reindex_collapsed_purchase_orders(socket.assigns.collapsed_purchase_orders, index)
     )}
  end

  @impl true
  def handle_event("add_line", %{"po-index" => po_index}, socket) do
    po_index = String.to_integer(po_index)

    purchase_orders =
      List.update_at(socket.assigns.entry["purchase_orders"], po_index, fn purchase_order ->
        update_in(purchase_order["lines"], &(&1 ++ [empty_line()]))
      end)

    entry = put_in(socket.assigns.entry["purchase_orders"], purchase_orders)

    {:noreply, assign(socket, :entry, entry)}
  end

  @impl true
  def handle_event("remove_line", %{"po-index" => po_index, "line-index" => line_index}, socket) do
    po_index = String.to_integer(po_index)
    line_index = String.to_integer(line_index)

    entry =
      update_in(socket.assigns.entry["purchase_orders"], fn purchase_orders ->
        List.update_at(purchase_orders, po_index, fn purchase_order ->
          lines = remove_at(purchase_order["lines"], line_index)

          if lines == [] do
            put_in(purchase_order["lines"], [empty_line()])
          else
            put_in(purchase_order["lines"], lines)
          end
        end)
      end)

    {:noreply, assign(socket, :entry, entry)}
  end

  @impl true
  def handle_event("toggle_purchase_order", %{"index" => index}, socket) do
    po_index = String.to_integer(index)

    collapsed_purchase_orders =
      if MapSet.member?(socket.assigns.collapsed_purchase_orders, po_index) do
        MapSet.delete(socket.assigns.collapsed_purchase_orders, po_index)
      else
        MapSet.put(socket.assigns.collapsed_purchase_orders, po_index)
      end

    {:noreply, assign(socket, :collapsed_purchase_orders, collapsed_purchase_orders)}
  end

  @impl true
  def handle_event("save", %{"work_package" => params}, socket) do
    entry = normalize_entry(params)

    with {:ok, attrs} <- validate_entry(entry),
         {:ok, work_package} <- Operations.save_work_package_entry(attrs) do
      {:noreply,
       socket
       |> put_flash(:info, "Work package saved")
       |> push_navigate(to: ~p"/work-packages/#{work_package.id}")}
    else
      {:error, errors} ->
        {:noreply,
         socket
         |> assign(:entry, entry)
         |> assign(:save_errors, List.wrap(errors))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <section class="mx-auto max-w-[1100px]">
        <BoonWeb.Components.Card.card
          variant="gradient"
          color="danger"
          rounded="extra_large"
          class="app-panel"
          padding="large"
        >
          <BoonWeb.Components.Card.card_content space="large">
            <div class="space-y-4">
              <h1 class="text-3xl font-semibold text-stone-50 sm:text-4xl">Work Package Entry</h1>
            </div>

            <BoonWeb.Components.Card.card
              variant="bordered"
              color="warning"
              rounded="large"
              class="bg-black/15"
              padding="medium"
            >
              <BoonWeb.Components.Card.card_content space="medium">
                <p class="app-kicker text-[0.68rem]">PDF / ZIP Import</p>

                <.form
                  for={@import_form}
                  id="import-form"
                  phx-change="queue_import_pdf"
                  phx-submit="import_pdf"
                  class="space-y-4"
                >
                  <BoonWeb.Components.FileField.file
                    upload={@uploads.purchase_order_pdf}
                    label="Purchase order files"
                  />

                  <BoonWeb.Components.Button.button
                    type="submit"
                    variant="shadow"
                    color="warning"
                    size="small"
                    icon="hero-document-arrow-up"
                  >
                    Import Files Into Form
                  </BoonWeb.Components.Button.button>
                </.form>
              </BoonWeb.Components.Card.card_content>
            </BoonWeb.Components.Card.card>

            <BoonWeb.Components.Card.card
              :if={@save_errors != []}
              variant="bordered"
              color="danger"
              rounded="large"
              class="bg-black/15"
              padding="medium"
            >
              <p class="font-semibold text-stone-50">The work package could not be saved.</p>

              <ul class="mt-3 space-y-2 text-sm text-rose-200">
                <li :for={error <- @save_errors}>{error}</li>
              </ul>
            </BoonWeb.Components.Card.card>

            <.form
              for={@form}
              id="intake-form"
              phx-change="change"
              phx-submit="save"
              class="space-y-6"
            >
              <BoonWeb.Components.Card.card
                variant="bordered"
                color="warning"
                rounded="large"
                class="bg-black/15"
                padding="medium"
              >
                <div>
                  <BoonWeb.Components.InputField.input
                    field={@form[:number]}
                    value={Map.get(@entry, "number", "")}
                    label="Work package number"
                    placeholder="10"
                    required
                    autocomplete="off"
                  />
                </div>
              </BoonWeb.Components.Card.card>

              <div class="space-y-4">
                <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                  <p class="app-kicker text-[0.68rem]">Purchase Orders</p>

                  <BoonWeb.Components.Button.button
                    type="button"
                    phx-click="add_purchase_order"
                    variant="shadow"
                    color="warning"
                    size="small"
                    icon="hero-plus"
                  >
                    Add Purchase Order
                  </BoonWeb.Components.Button.button>
                </div>

                <BoonWeb.Components.PurchaseOrderEditor.editor
                  :for={
                    {purchase_order, po_index} <-
                      Enum.with_index(Map.get(@entry, "purchase_orders", []))
                  }
                  form_name={@form.name}
                  po_index={po_index}
                  po_number={Map.get(purchase_order, "po_number", "")}
                  order_date={Map.get(purchase_order, "order_date", "")}
                  revision_date={Map.get(purchase_order, "revision_date", "")}
                  reference={Map.get(purchase_order, "reference", "")}
                  ship_to={Map.get(purchase_order, "ship_to", "")}
                  lines={Map.get(purchase_order, "lines", [])}
                  collapsed={MapSet.member?(@collapsed_purchase_orders, po_index)}
                  purchase_order_count={length(Map.get(@entry, "purchase_orders", []))}
                />
              </div>

              <div class="space-y-3">
                <div
                  :if={@import_errors != []}
                  class="rounded-[1rem] border border-rose-300/30 bg-rose-400/10 px-4 py-3 text-sm text-rose-100"
                >
                  <ul class="space-y-1">
                    <li :for={error <- @import_errors}>{error}</li>
                  </ul>
                </div>

                <div
                  :if={@import_warnings != []}
                  class="rounded-[1rem] border border-amber-300/20 bg-amber-300/10 px-4 py-3 text-sm text-amber-100"
                >
                  <ul class="space-y-1">
                    <li :for={warning <- @import_warnings}>{warning}</li>
                  </ul>
                </div>

                <div
                  :if={upload_errors?(@uploads.purchase_order_pdf)}
                  class="rounded-[1rem] border border-rose-300/30 bg-rose-400/10 px-4 py-3 text-sm text-rose-100"
                >
                  <ul class="space-y-1">
                    <li :for={error <- upload_error_messages(@uploads.purchase_order_pdf)}>
                      {error}
                    </li>
                  </ul>
                </div>
              </div>

              <BoonWeb.Components.Card.card
                variant="bordered"
                color="danger"
                rounded="large"
                class="bg-black/15"
                padding="medium"
              >
                <div class="flex flex-wrap items-center justify-end gap-3">
                  <div class="flex flex-wrap gap-3">
                    <BoonWeb.Components.Button.button_link
                      navigate={~p"/work-packages"}
                      variant="outline"
                      color="warning"
                      size="medium"
                    >
                      View Work Packages
                    </BoonWeb.Components.Button.button_link>
                    <BoonWeb.Components.Button.button
                      type="submit"
                      variant="shadow"
                      color="danger"
                      size="medium"
                      icon="hero-check"
                    >
                      Save Work Package
                    </BoonWeb.Components.Button.button>
                  </div>
                </div>
              </BoonWeb.Components.Card.card>
            </.form>
          </BoonWeb.Components.Card.card_content>
        </BoonWeb.Components.Card.card>
      </section>
    </Layouts.app>
    """
  end

  defp empty_entry do
    %{"number" => "", "purchase_orders" => [empty_purchase_order()]}
  end

  defp empty_purchase_order do
    %{
      "po_number" => "",
      "order_date" => "",
      "revision_date" => "",
      "reference" => "",
      "ship_to" => "",
      "lines" => [empty_line()]
    }
  end

  defp empty_line do
    %{"line" => "", "item_number" => "", "ship_date" => "", "quantity" => ""}
  end

  defp normalize_entry(params) do
    %{
      "number" => Map.get(params, "number", ""),
      "purchase_orders" =>
        params
        |> Map.get("purchase_orders", %{})
        |> sort_param_collection()
        |> Enum.map(fn purchase_order ->
          %{
            "po_number" => Map.get(purchase_order, "po_number", ""),
            "order_date" => Map.get(purchase_order, "order_date", ""),
            "revision_date" => Map.get(purchase_order, "revision_date", ""),
            "reference" => Map.get(purchase_order, "reference", ""),
            "ship_to" => Map.get(purchase_order, "ship_to", ""),
            "lines" =>
              purchase_order
              |> Map.get("lines", %{})
              |> sort_param_collection()
              |> Enum.map(fn line ->
                %{
                  "line" => Map.get(line, "line", ""),
                  "item_number" => Map.get(line, "item_number", ""),
                  "ship_date" => Map.get(line, "ship_date", ""),
                  "quantity" => Map.get(line, "quantity", "")
                }
              end)
              |> ensure_line()
          }
        end)
        |> ensure_purchase_order()
    }
  end

  defp validate_entry(entry) do
    {purchase_orders, errors} =
      entry["purchase_orders"]
      |> Enum.with_index(1)
      |> Enum.reduce({[], []}, fn {purchase_order, purchase_order_index},
                                  {purchase_orders, errors} ->
        {lines, line_errors} = validate_lines(purchase_order["lines"], purchase_order_index)

        {order_date, order_date_error} =
          parse_optional_date(
            purchase_order["order_date"],
            "PO #{purchase_order_index} order date"
          )

        {revision_date, revision_date_error} =
          parse_optional_date(
            purchase_order["revision_date"],
            "PO #{purchase_order_index} revision date"
          )

        purchase_order_errors =
          errors ++
            line_errors ++
            List.wrap(order_date_error) ++
            List.wrap(revision_date_error) ++
            validate_ship_to(purchase_order["ship_to"], purchase_order_index) ++
            required_field_error(purchase_order["po_number"], "PO #{purchase_order_index} number")

        normalized_ship_to = normalize_text(purchase_order["ship_to"])

        normalized_purchase_order = %{
          po_number: normalize_text(purchase_order["po_number"]),
          order_date: order_date,
          revision_date: revision_date,
          reference: normalize_optional_text(purchase_order["reference"]),
          ship_to: normalized_ship_to,
          lines: lines
        }

        {[normalized_purchase_order | purchase_orders], purchase_order_errors}
      end)

    errors = required_field_error(entry["number"], "Work package number") ++ errors

    if errors == [] do
      {:ok,
       %{
         number: normalize_text(entry["number"]),
         purchase_orders: Enum.reverse(purchase_orders)
       }}
    else
      {:error, errors}
    end
  end

  defp validate_lines(lines, purchase_order_index) do
    {normalized_lines, errors} =
      lines
      |> Enum.with_index(1)
      |> Enum.reduce({[], []}, fn {line, line_index}, {normalized_lines, errors} ->
        {line_number, line_number_error} =
          parse_positive_integer(
            line["line"],
            "PO #{purchase_order_index} line #{line_index} line number"
          )

        {quantity, quantity_error} =
          parse_positive_integer(
            line["quantity"],
            "PO #{purchase_order_index} line #{line_index} quantity"
          )

        {ship_date, ship_date_error} =
          parse_optional_date(
            line["ship_date"],
            "PO #{purchase_order_index} line #{line_index} ship date"
          )

        line_errors =
          errors ++
            required_field_error(
              line["item_number"],
              "PO #{purchase_order_index} line #{line_index} item number"
            ) ++
            List.wrap(line_number_error) ++
            List.wrap(quantity_error) ++
            List.wrap(ship_date_error)

        normalized_line = %{
          line: line_number,
          item_number: normalize_text(line["item_number"]),
          ship_date: ship_date,
          quantity: quantity
        }

        {[normalized_line | normalized_lines], line_errors}
      end)

    normalized_lines = Enum.reverse(normalized_lines)

    {normalized_lines, errors}
  end

  defp parse_positive_integer(value, label) do
    case normalize_text(value) do
      "" ->
        {nil, "#{label} is required"}

      normalized ->
        case Integer.parse(normalized) do
          {integer, ""} when integer > 0 -> {integer, nil}
          _ -> {nil, "#{label} must be a positive whole number"}
        end
    end
  end

  defp parse_optional_date(value, label) do
    case normalize_text(value) do
      "" ->
        {nil, nil}

      normalized ->
        case Date.from_iso8601(normalized) do
          {:ok, date} -> {date, nil}
          {:error, _reason} -> {nil, "#{label} must be a valid date"}
        end
    end
  end

  defp required_field_error(value, label) do
    if normalize_text(value) == "", do: ["#{label} is required"], else: []
  end

  defp validate_ship_to(value, purchase_order_index) do
    case normalize_text(value) do
      "" ->
        ["PO #{purchase_order_index} ship to is required"]

      ship_to ->
        if ShippingLocation.valid_value?(ship_to) do
          []
        else
          ["PO #{purchase_order_index} ship to must be one of the supported shipping locations"]
        end
    end
  end

  defp normalize_text(value), do: value |> to_string() |> String.trim()

  defp normalize_optional_text(value) do
    case normalize_text(value) do
      "" -> nil
      normalized -> normalized
    end
  end

  defp sort_param_collection(values) when is_list(values), do: values

  defp sort_param_collection(values) when is_map(values) do
    values
    |> Enum.sort_by(fn {index, _value} -> String.to_integer(index) end)
    |> Enum.map(fn {_index, value} -> value end)
  end

  defp sort_param_collection(_values), do: []

  defp ensure_purchase_order([]), do: [empty_purchase_order()]
  defp ensure_purchase_order(purchase_orders), do: purchase_orders

  defp ensure_line([]), do: [empty_line()]
  defp ensure_line(lines), do: lines

  defp import_entry(entry, %{purchase_orders: purchase_orders}) do
    %{
      "number" => entry["number"],
      "purchase_orders" => Enum.map(purchase_orders, &stringify_purchase_order/1)
    }
  end

  defp stringify_purchase_order(purchase_order) do
    %{
      "po_number" => purchase_order.po_number,
      "order_date" => stringify_date(purchase_order.order_date),
      "revision_date" => stringify_date(purchase_order.revision_date),
      "reference" => purchase_order.reference || "",
      "ship_to" => purchase_order.ship_to || "",
      "lines" => Enum.map(purchase_order.lines, &stringify_line/1)
    }
  end

  defp stringify_line(line) do
    %{
      "line" => Integer.to_string(line.line),
      "item_number" => line.item_number,
      "ship_date" => stringify_date(line.ship_date),
      "quantity" => Integer.to_string(line.quantity)
    }
  end

  defp stringify_date(%Date{} = date), do: Date.to_iso8601(date)
  defp stringify_date(_date), do: ""

  defp upload_errors?(upload) do
    upload.entries != [] and upload_error_messages(upload) != []
  end

  defp upload_error_messages(upload) do
    for entry <- upload.entries,
        error <- upload_errors(upload, entry) do
      case error do
        :too_large -> "One of the selected files is larger than the allowed upload size."
        :not_accepted -> "Only PDF and ZIP files are accepted for import."
        :too_many_files -> "Too many files were selected for one import."
        other -> "Upload failed: #{inspect(other)}"
      end
    end
  end

  defp merge_import_results(results) do
    Enum.reduce(results, %{purchase_orders: [], warnings: [], errors: []}, fn result, acc ->
      %{
        purchase_orders: acc.purchase_orders ++ result.purchase_orders,
        warnings: acc.warnings ++ result.warnings,
        errors: acc.errors ++ result.errors
      }
    end)
  end

  defp remove_at(list, index) when is_binary(index), do: remove_at(list, String.to_integer(index))
  defp remove_at(list, index), do: List.delete_at(list, index)

  defp reindex_collapsed_purchase_orders(collapsed_purchase_orders, removed_index)
       when is_binary(removed_index) do
    reindex_collapsed_purchase_orders(collapsed_purchase_orders, String.to_integer(removed_index))
  end

  defp reindex_collapsed_purchase_orders(collapsed_purchase_orders, removed_index) do
    collapsed_purchase_orders
    |> Enum.reduce(MapSet.new(), fn index, acc ->
      cond do
        index < removed_index -> MapSet.put(acc, index)
        index > removed_index -> MapSet.put(acc, index - 1)
        true -> acc
      end
    end)
  end
end
