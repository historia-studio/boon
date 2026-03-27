defmodule BoonWeb.WorkPackageLive.PurchaseOrderShow do
  use BoonWeb, :live_view

  alias Boon.Operations
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
         |> assign(:work_package, work_package)
         |> assign(:purchase_order, purchase_order)}
    end
  end

  @impl true
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

          <div
            :if={@purchase_order.ship_to}
            class="mt-4 rounded-[1.25rem] border border-white/10 bg-black/20 px-4 py-4"
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
