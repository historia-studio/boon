defmodule BoonWeb.WorkPackageLive.Show do
  use BoonWeb, :live_view

  alias Boon.Operations
  alias Boon.Printing.{Dispatcher, LabelTransport, PalletTagTransport}
  alias Boon.ShippingLocation

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    work_package = Operations.get_work_package!(id)

    {:ok,
     socket
     |> assign(:current_scope, nil)
     |> assign(:work_package, work_package)}
  end

  @impl true
  def handle_event("print_work_package_labels", _params, socket) do
    {:noreply,
     socket
     |> print_labels(
       Dispatcher.dispatch_work_package_labels(
         socket.assigns.work_package,
         label_dispatch_options()
       )
     )}
  end

  def handle_event("print_work_package_pallet_tags", _params, socket) do
    {:noreply,
     socket
     |> print_pallet_tags(
       Dispatcher.dispatch_work_package_pallet_tags(
         socket.assigns.work_package,
         pallet_tag_dispatch_options()
       )
     )}
  end

  def handle_event("delete_work_package", _params, socket) do
    case Operations.delete_work_package(socket.assigns.work_package) do
      :ok ->
        {:noreply,
         socket
         |> put_flash(:info, "Work package deleted.")
         |> push_navigate(to: ~p"/work-packages")}

      {:error, [message | _rest]} ->
        {:noreply, put_flash(socket, :error, message)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <section class="space-y-6">
        <BoonWeb.Components.Card.card
          variant="gradient"
          color="danger"
          rounded="extra_large"
          class="app-panel"
          padding="large"
        >
          <BoonWeb.Components.Card.card_content space="large">
            <div class="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
              <div class="space-y-3">
                <BoonWeb.Components.Badge.badge
                  color="warning"
                  variant="bordered"
                  rounded="full"
                  class="w-fit text-[0.68rem] font-medium uppercase tracking-[0.24em]"
                >
                  Work Package
                </BoonWeb.Components.Badge.badge>

                <h1 class="text-4xl font-semibold text-stone-50">WP {@work_package.number}</h1>
              </div>

              <div class="flex flex-wrap gap-3">
                <BoonWeb.Components.Button.button
                  id="print-work-package-pallet-tags"
                  type="button"
                  variant="outline"
                  color="danger"
                  icon="hero-document-duplicate"
                  size="medium"
                  phx-click="print_work_package_pallet_tags"
                >
                  Print All Pallet Tags
                </BoonWeb.Components.Button.button>
                <BoonWeb.Components.Button.button
                  id="print-work-package-labels"
                  type="button"
                  variant="shadow"
                  color="warning"
                  icon="hero-printer"
                  size="medium"
                  phx-click="print_work_package_labels"
                >
                  Print All Labels
                </BoonWeb.Components.Button.button>
                <BoonWeb.Components.Button.button_link
                  navigate={~p"/intake"}
                  variant="shadow"
                  color="danger"
                  icon="hero-plus"
                  size="medium"
                >
                  Enter Another
                </BoonWeb.Components.Button.button_link>
                <BoonWeb.Components.Button.button_link
                  navigate={~p"/work-packages"}
                  variant="outline"
                  color="warning"
                  size="medium"
                >
                  All Work Packages
                </BoonWeb.Components.Button.button_link>
                <BoonWeb.Components.Button.button
                  id="delete-work-package"
                  type="button"
                  variant="outline"
                  color="danger"
                  icon="hero-trash"
                  size="medium"
                  phx-click="delete_work_package"
                >
                  Delete Work Package
                </BoonWeb.Components.Button.button>
              </div>
            </div>

            <div class="grid gap-4 md:grid-cols-3">
              <BoonWeb.Components.Card.card
                variant="bordered"
                color="danger"
                rounded="large"
                class="bg-black/20"
                padding="medium"
              >
                <p class="text-sm text-stone-400">Purchase Orders</p>
                <p class="mt-3 text-3xl font-semibold text-stone-50">
                  {length(@work_package.purchase_orders)}
                </p>
              </BoonWeb.Components.Card.card>

              <BoonWeb.Components.Card.card
                variant="bordered"
                color="warning"
                rounded="large"
                class="bg-black/20"
                padding="medium"
              >
                <p class="text-sm text-stone-400">PO Lines</p>
                <p class="mt-3 text-3xl font-semibold text-stone-50">{line_count(@work_package)}</p>
              </BoonWeb.Components.Card.card>

              <BoonWeb.Components.Card.card
                variant="bordered"
                color="dark"
                rounded="large"
                class="bg-black/20"
                padding="medium"
              >
                <p class="text-sm text-stone-400">Status</p>
                <p class="mt-3 text-lg font-semibold text-stone-50">Manual entry complete</p>
              </BoonWeb.Components.Card.card>
            </div>
          </BoonWeb.Components.Card.card_content>
        </BoonWeb.Components.Card.card>

        <BoonWeb.Components.Card.card
          variant="bordered"
          color="warning"
          rounded="extra_large"
          class="app-panel"
          padding="large"
        >
          <BoonWeb.Components.Card.card_content space="large">
            <div class="space-y-2">
              <p class="app-kicker text-[0.68rem]">Purchase Orders</p>
              <h2 class="text-2xl font-semibold text-stone-50">Open a purchase order page</h2>
              <p class="text-sm text-stone-400">
                Click any row to open a dedicated purchase-order page with line-level detail and print actions.
              </p>
            </div>

            <BoonWeb.Components.Table.table
              id="purchase-orders-table"
              rows={@work_package.purchase_orders}
              row_id={fn purchase_order -> "purchase-order-row-#{purchase_order.id}" end}
              row_click={
                fn purchase_order ->
                  JS.navigate(
                    ~p"/work-packages/#{@work_package.id}/purchase-orders/#{purchase_order.id}"
                  )
                end
              }
              variant="base_hoverable"
              rounded="large"
              class="text-stone-200"
            >
              <:col :let={purchase_order} label="PO Number">
                <span class="font-semibold text-stone-50">PO {purchase_order.po_number}</span>
              </:col>
              <:col :let={purchase_order} label="Reference">
                <span class="line-clamp-1 text-stone-400">{purchase_order.reference || "-"}</span>
              </:col>
              <:col :let={purchase_order} label="Ship To">
                {ship_to_label(purchase_order.ship_to)}
              </:col>
              <:col :let={purchase_order} label="PO Lines">
                {length(purchase_order.lines)}
              </:col>
              <:col :let={purchase_order} label="Revision">
                <span class="text-stone-400">{format_date(purchase_order.revision_date)}</span>
              </:col>
            </BoonWeb.Components.Table.table>
          </BoonWeb.Components.Card.card_content>
        </BoonWeb.Components.Card.card>
      </section>
    </Layouts.app>
    """
  end

  defp line_count(work_package) do
    Enum.reduce(work_package.purchase_orders, 0, fn purchase_order, total ->
      total + length(purchase_order.lines)
    end)
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

  defp ship_to_label(nil), do: "-"
  defp ship_to_label(ship_to), do: ShippingLocation.label(ship_to)

  defp format_date(%Date{} = date), do: Calendar.strftime(date, "%Y-%m-%d")
  defp format_date(_date), do: "-"
end
