defmodule BoonWeb.WorkPackageLive.PurchaseOrderShow do
  use BoonWeb, :live_view

  alias Boon.Operations
  alias BoonWeb.Components.PurchaseOrderEditor
  alias Boon.Printing.{Dispatcher, ItemNumber, LabelTransport, PalletTagTransport}
  alias Boon.ShippingLocation

  @impl true
  def mount(
        %{"work_package_id" => work_package_id, "purchase_order_id" => purchase_order_id},
        _session,
        socket
      ) do
    work_package = Operations.get_work_package!(work_package_id)

    case find_purchase_order(work_package, purchase_order_id) do
      nil ->
        {:ok,
         socket
         |> assign(:current_scope, nil)
         |> put_flash(:error, "That purchase order could not be found.")
         |> push_navigate(to: ~p"/work-packages/#{work_package.id}")}

      purchase_order ->
        {:ok,
         socket
         |> assign(:current_scope, nil)
         |> assign(:editing_purchase_order, false)
         |> assign(:entry, stringify_purchase_order(purchase_order))
         |> assign(:form, to_form(%{}, as: :purchase_order))
         |> assign(:save_errors, [])
         |> assign(:work_package, work_package)
         |> assign(:purchase_order, purchase_order)}
    end
  end

  @impl true
  def handle_event("start_edit_purchase_order", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing_purchase_order, true)
     |> assign(:entry, stringify_purchase_order(socket.assigns.purchase_order))
     |> assign(:save_errors, [])}
  end

  def handle_event("cancel_edit_purchase_order", _params, socket) do
    {:noreply,
     socket
     |> assign(:editing_purchase_order, false)
     |> assign(:entry, stringify_purchase_order(socket.assigns.purchase_order))
     |> assign(:save_errors, [])}
  end

  def handle_event("change_purchase_order", %{"purchase_order" => params}, socket) do
    {:noreply,
     socket
     |> assign(:entry, normalize_purchase_order_entry(params))
     |> assign(:save_errors, [])}
  end

  def handle_event("add_line", %{"po-index" => _po_index}, socket) do
    entry = update_in(socket.assigns.entry["lines"], &(&1 ++ [empty_line()]))

    {:noreply, assign(socket, :entry, entry)}
  end

  def handle_event("remove_line", %{"po-index" => _po_index, "line-index" => line_index}, socket) do
    lines = remove_at(socket.assigns.entry["lines"], line_index)

    entry =
      if lines == [] do
        put_in(socket.assigns.entry["lines"], [empty_line()])
      else
        put_in(socket.assigns.entry["lines"], lines)
      end

    {:noreply, assign(socket, :entry, entry)}
  end

  def handle_event("save_purchase_order", %{"purchase_order" => params}, socket) do
    entry = normalize_purchase_order_entry(params)

    with {:ok, attrs} <- validate_purchase_order_entry(entry),
         {:ok, _purchase_order} <-
           Operations.update_purchase_order_entry(socket.assigns.purchase_order, attrs) do
      work_package = Operations.get_work_package!(socket.assigns.work_package.id)
      purchase_order = find_purchase_order(work_package, socket.assigns.purchase_order.id)

      {:noreply,
       socket
       |> assign(:editing_purchase_order, false)
       |> assign(:entry, stringify_purchase_order(purchase_order))
       |> assign(:purchase_order, purchase_order)
       |> assign(:save_errors, [])
       |> assign(:work_package, work_package)
       |> put_flash(:info, "Purchase order updated")}
    else
      {:error, errors} ->
        {:noreply,
         socket
         |> assign(:entry, entry)
         |> assign(:save_errors, List.wrap(errors))}
    end
  end

  def handle_event("delete_purchase_order", _params, socket) do
    case Operations.delete_purchase_order(socket.assigns.purchase_order) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Purchase order deleted.")
         |> push_navigate(to: ~p"/work-packages/#{socket.assigns.work_package.id}")}

      {:error, [message | _rest]} ->
        {:noreply, put_flash(socket, :error, message)}
    end
  end

  def handle_event("print_purchase_order_labels", _params, socket) do
    {:noreply,
     socket
     |> print_labels(
       Dispatcher.dispatch_purchase_order_labels(
         socket.assigns.work_package,
         socket.assigns.purchase_order,
         label_dispatch_options()
       )
     )}
  end

  def handle_event("print_purchase_order_pallet_tags", _params, socket) do
    {:noreply,
     socket
     |> print_pallet_tags(
       Dispatcher.dispatch_purchase_order_pallet_tags(
         socket.assigns.work_package,
         socket.assigns.purchase_order,
         pallet_tag_dispatch_options()
       )
     )}
  end

  def handle_event("print_line_labels", %{"line-id" => line_id}, socket) do
    case find_line(socket.assigns.purchase_order, line_id) do
      nil ->
        {:noreply, put_flash(socket, :error, "That PO line could not be found.")}

      line ->
        {:noreply,
         socket
         |> print_labels(
           Dispatcher.dispatch_purchase_order_line_labels(
             socket.assigns.work_package,
             socket.assigns.purchase_order,
             line,
             label_dispatch_options()
           )
         )}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <section class="space-y-6">
        <div class="grid gap-4 lg:grid-cols-[1.1fr_0.9fr] lg:items-start">
          <div>
            <h2 class="mt-3 text-2xl font-semibold text-stone-50">
              PO {@purchase_order.po_number}
            </h2>
            <p :if={@purchase_order.reference} class="mt-2 text-sm text-stone-400">
              {@purchase_order.reference}
            </p>
          </div>
          <div class="flex flex-wrap gap-3 justify-end w-full">
            <BoonWeb.Components.Button.button
              :if={!@editing_purchase_order}
              id="edit-purchase-order"
              type="button"
              variant="subtle"
              color="warning"
              icon="hero-pencil-square"
              size="medium"
              phx-click="start_edit_purchase_order"
            >
              Edit PO
            </BoonWeb.Components.Button.button>
            <BoonWeb.Components.Button.button
              :if={!@editing_purchase_order}
              id="delete-purchase-order"
              type="button"
              variant="outline"
              color="danger"
              icon="hero-trash"
              size="medium"
              phx-click="delete_purchase_order"
            >
              Delete PO
            </BoonWeb.Components.Button.button>
            <BoonWeb.Components.Button.button
              id="print-purchase-order-pallet-tags"
              type="button"
              variant="outline"
              color="danger"
              icon="hero-document-duplicate"
              size="medium"
              phx-click="print_purchase_order_pallet_tags"
            >
              Print PO Pallet Tags
            </BoonWeb.Components.Button.button>
            <BoonWeb.Components.Button.button
              id="print-purchase-order-labels"
              type="button"
              variant="shadow"
              color="warning"
              icon="hero-printer"
              size="medium"
              phx-click="print_purchase_order_labels"
            >
              Print PO Labels
            </BoonWeb.Components.Button.button>
            <BoonWeb.Components.Button.button_link
              navigate={~p"/work-packages/#{@work_package.id}"}
              variant="outline"
              color="warning"
              size="medium"
            >
              Back to Work Package
            </BoonWeb.Components.Button.button_link>
          </div>
        </div>

        <%= if @editing_purchase_order do %>
          <BoonWeb.Components.Card.card
            :if={@save_errors != []}
            variant="bordered"
            color="danger"
            rounded="large"
            class="bg-black/15"
            padding="medium"
          >
            <p class="font-semibold text-stone-50">The purchase order could not be saved.</p>

            <ul class="mt-3 space-y-2 text-sm text-rose-200">
              <li :for={error <- @save_errors}>{error}</li>
            </ul>
          </BoonWeb.Components.Card.card>

          <.form
            for={@form}
            id="purchase-order-edit-form"
            phx-change="change_purchase_order"
            phx-submit="save_purchase_order"
            class="space-y-6"
          >
            <PurchaseOrderEditor.editor
              form_name={@form.name}
              po_index={0}
              po_number={Map.get(@entry, "po_number", "")}
              order_date={Map.get(@entry, "order_date", "")}
              revision_date={Map.get(@entry, "revision_date", "")}
              reference={Map.get(@entry, "reference", "")}
              ship_to={Map.get(@entry, "ship_to", "")}
              lines={Map.get(@entry, "lines", [])}
              show_toggle={false}
              show_remove_purchase_order={false}
            />

            <BoonWeb.Components.Card.card
              variant="bordered"
              color="danger"
              rounded="large"
              class="bg-black/15"
              padding="medium"
            >
              <div class="flex flex-wrap items-center justify-end gap-3">
                <BoonWeb.Components.Button.button
                  id="cancel-edit-purchase-order"
                  type="button"
                  variant="outline"
                  color="warning"
                  size="medium"
                  phx-click="cancel_edit_purchase_order"
                >
                  Cancel
                </BoonWeb.Components.Button.button>
                <BoonWeb.Components.Button.button
                  id="save-purchase-order"
                  type="submit"
                  variant="shadow"
                  color="danger"
                  size="medium"
                  icon="hero-check"
                >
                  Save Purchase Order
                </BoonWeb.Components.Button.button>
              </div>
            </BoonWeb.Components.Card.card>
          </.form>
        <% else %>
          <div id={"purchase-order-detail-#{@purchase_order.id}"} class="space-y-6">
            <div class="grid gap-4 lg:grid-cols-[0.9fr_1.1fr] lg:items-start">
              <div
                :if={@purchase_order.ship_to}
                class="rounded-[1.25rem] border border-white/10 bg-black/20 px-4 py-4"
              >
                <p class="text-xs uppercase tracking-[0.24em] text-stone-500">Ship To</p>

                <p class="mt-2 text-sm font-semibold text-stone-100">
                  {ShippingLocation.label(@purchase_order.ship_to)}
                </p>

                <p
                  :for={line <- ShippingLocation.address_lines(@purchase_order.ship_to)}
                  class="text-sm text-stone-400"
                >
                  {line}
                </p>
              </div>

              <dl class="grid gap-3 sm:grid-cols-3">
                <div class="app-panel-soft rounded-[1.25rem] px-4 py-4">
                  <dt class="text-xs uppercase tracking-[0.24em] text-stone-500">Order Date</dt>

                  <dd class="mt-2 text-sm text-stone-100">
                    {format_date(@purchase_order.order_date)}
                  </dd>
                </div>

                <div class="app-panel-soft rounded-[1.25rem] px-4 py-4">
                  <dt class="text-xs uppercase tracking-[0.24em] text-stone-500">Revision Date</dt>

                  <dd class="mt-2 text-sm text-stone-100">
                    {format_date(@purchase_order.revision_date)}
                  </dd>
                </div>

                <div class="app-panel-soft rounded-[1.25rem] px-4 py-4">
                  <dt class="text-xs uppercase tracking-[0.24em] text-stone-500">PO Lines</dt>

                  <dd class="mt-2 text-sm text-stone-100">{length(@purchase_order.lines)}</dd>
                </div>
              </dl>
            </div>

            <BoonWeb.Components.Table.table
              id={"purchase-order-lines-#{@purchase_order.id}"}
              rows={@purchase_order.lines}
              row_id={fn line -> "purchase-order-line-#{line.id}" end}
              variant="base"
              rounded="large"
              class="text-stone-200"
            >
              <:col :let={line} label="Line">
                <span class="font-semibold text-stone-50">{line.line}</span>
              </:col>

              <:col :let={line} label="Item Number / Description">{line.item_number}</:col>

              <:col :let={line} label="Ship Date">
                <span class="text-stone-400">{format_date(line.ship_date)}</span>
              </:col>

              <:col :let={line} label="Quantity">{line.quantity}</:col>

              <:action :let={line}>
                <BoonWeb.Components.Button.button
                  id={"print-line-labels-#{line.id}"}
                  type="button"
                  variant="ghost"
                  color="warning"
                  size="extra_small"
                  icon="hero-printer"
                  circle
                  title={line_print_title(line)}
                  aria-label={line_print_title(line)}
                  phx-click="print_line_labels"
                  phx-value-line-id={line.id}
                  disabled={!ItemNumber.label_item?(line.item_number)}
                  class={
                    if(!ItemNumber.label_item?(line.item_number),
                      do: "cursor-not-allowed opacity-40"
                    )
                  }
                />
              </:action>
            </BoonWeb.Components.Table.table>
          </div>
        <% end %>
      </section>
    </Layouts.app>
    """
  end

  defp print_labels(socket, {:ok, result}) do
    case result.status do
      :completed ->
        put_flash(
          socket,
          :info,
          "Printed #{result.label_count} labels to #{result.target_printer}."
        )

      :skipped ->
        put_flash(socket, :error, result.error || "No labels were available to print.")

      :failed ->
        put_flash(socket, :error, result.error || "Label printing failed.")
    end
  end

  defp print_pallet_tags(socket, {:ok, result}) do
    case result.status do
      :completed ->
        put_flash(
          socket,
          :info,
          "Printed #{result.label_count} pallet tags to #{result.target_printer}."
        )

      :skipped ->
        put_flash(socket, :error, result.error || "No pallet tags were available to print.")

      :failed ->
        put_flash(socket, :error, result.error || "Pallet tag printing failed.")
    end
  end

  defp find_purchase_order(work_package, purchase_order_id) do
    Enum.find(work_package.purchase_orders, &(&1.id == purchase_order_id))
  end

  defp find_line(purchase_order, line_id) do
    Enum.find(purchase_order.lines, &(&1.id == line_id))
  end

  defp empty_line do
    %{"line" => "", "item_number" => "", "ship_date" => "", "quantity" => ""}
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

  defp normalize_purchase_order_entry(params) do
    params
    |> Map.get("purchase_orders", %{})
    |> sort_param_collection()
    |> List.first(%{"lines" => [empty_line()]})
    |> then(fn purchase_order ->
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
  end

  defp validate_purchase_order_entry(entry) do
    {lines, errors} = validate_lines(entry["lines"])

    {order_date, order_date_error} = parse_optional_date(entry["order_date"], "Order date")

    {revision_date, revision_date_error} =
      parse_optional_date(entry["revision_date"], "Revision date")

    errors =
      errors ++
        required_field_error(entry["po_number"], "PO number") ++
        List.wrap(order_date_error) ++
        List.wrap(revision_date_error) ++
        validate_ship_to(entry["ship_to"])

    if errors == [] do
      {:ok,
       %{
         po_number: normalize_text(entry["po_number"]),
         order_date: order_date,
         revision_date: revision_date,
         reference: normalize_optional_text(entry["reference"]),
         ship_to: normalize_text(entry["ship_to"]),
         lines: lines
       }}
    else
      {:error, errors}
    end
  end

  defp validate_lines(lines) do
    lines
    |> Enum.with_index(1)
    |> Enum.reduce({[], []}, fn {line, line_index}, {normalized_lines, errors} ->
      {line_number, line_number_error} =
        parse_positive_integer(line["line"], "Line #{line_index} line number")

      {quantity, quantity_error} =
        parse_positive_integer(line["quantity"], "Line #{line_index} quantity")

      {ship_date, ship_date_error} =
        parse_optional_date(line["ship_date"], "Line #{line_index} ship date")

      line_errors =
        errors ++
          required_field_error(line["item_number"], "Line #{line_index} item number") ++
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
    |> then(fn {normalized_lines, errors} -> {Enum.reverse(normalized_lines), errors} end)
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

  defp validate_ship_to(value) do
    case normalize_text(value) do
      "" ->
        ["Ship to is required"]

      ship_to ->
        if ShippingLocation.valid_value?(ship_to) do
          []
        else
          ["Ship to must be one of the supported shipping locations"]
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

  defp ensure_line([]), do: [empty_line()]
  defp ensure_line(lines), do: lines

  defp remove_at(list, index) when is_binary(index), do: remove_at(list, String.to_integer(index))
  defp remove_at(list, index), do: List.delete_at(list, index)

  defp label_dispatch_options do
    printing_config = Application.get_env(:boon, :printing, [])

    [
      label_transport: Keyword.get(printing_config, :label_transport_module, LabelTransport),
      label_transport_opts: Keyword.get(printing_config, :label_transport_opts, [])
    ]
  end

  defp pallet_tag_dispatch_options do
    printing_config = Application.get_env(:boon, :printing, [])

    [
      pallet_tag_transport:
        Keyword.get(printing_config, :pallet_tag_transport_module, PalletTagTransport),
      pallet_tag_transport_opts: Keyword.get(printing_config, :pallet_tag_transport_opts, [])
    ]
  end

  defp line_print_title(line) do
    if ItemNumber.label_item?(line.item_number) do
      "Print labels for line #{line.line}"
    else
      "Labels are not printed for this line"
    end
  end

  defp format_date(%Date{} = date), do: Calendar.strftime(date, "%Y-%m-%d")
  defp format_date(_date), do: "-"
end
