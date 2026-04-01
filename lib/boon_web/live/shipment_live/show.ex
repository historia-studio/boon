defmodule BoonWeb.ShipmentLive.Show do
  use BoonWeb, :live_view

  alias Boon.Operations
  alias Boon.Printing.{Dispatcher, PalletTagTransport}
  alias Boon.ShippingLocation

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    shipment = Operations.get_shipment!(id)

    {:ok,
     socket
     |> assign(:current_scope, nil)
     |> assign(:shipment, shipment)}
  end

  @impl true
  def handle_event("reprint_packing_slip", _params, socket) do
    {:noreply,
     socket
     |> put_flash(:info, nil)
     |> put_flash(:error, nil)
     |> reprint_packing_slip(
       Dispatcher.dispatch_shipment_packing_slip(
         socket.assigns.shipment,
         packing_slip_dispatch_options()
       )
     )}
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
                  Shipment
                </BoonWeb.Components.Badge.badge>

                <h1 class="text-4xl font-semibold text-stone-50">{shipment_heading(@shipment)}</h1>

                <p class="text-sm text-stone-400">
                  Work Package {@shipment.work_package.number} · {shipment_destination_label(
                    @shipment
                  )}
                </p>
              </div>

              <div class="flex flex-wrap gap-3">
                <BoonWeb.Components.Button.button
                  id="reprint-packing-slip"
                  type="button"
                  variant="shadow"
                  color="warning"
                  icon="hero-printer"
                  size="medium"
                  phx-click="reprint_packing_slip"
                >
                  Reprint Packing Slip
                </BoonWeb.Components.Button.button>
                <BoonWeb.Components.Button.button_link
                  id="download-packing-slip"
                  href={~p"/shipments/#{@shipment.id}/packing-slip"}
                  variant="outline"
                  color="warning"
                  icon="hero-arrow-down-tray"
                  size="medium"
                  download
                >
                  Download PDF
                </BoonWeb.Components.Button.button_link>
                <BoonWeb.Components.Button.button_link
                  navigate={~p"/shipments"}
                  variant="outline"
                  color="warning"
                  size="medium"
                >
                  All Shipments
                </BoonWeb.Components.Button.button_link>
                <BoonWeb.Components.Button.button_link
                  navigate={~p"/work-packages/#{@shipment.work_package.id}"}
                  variant="outline"
                  color="danger"
                  size="medium"
                >
                  Open Work Package
                </BoonWeb.Components.Button.button_link>
              </div>
            </div>

            <div class="grid gap-4 md:grid-cols-4">
              <BoonWeb.Components.Card.card
                variant="bordered"
                color="danger"
                rounded="large"
                class="bg-black/20"
                padding="medium"
              >
                <p class="text-sm text-stone-400">Confirmed</p>

                <p class="mt-3 text-lg font-semibold text-stone-50">
                  {format_datetime(@shipment.confirmed_at)}
                </p>
              </BoonWeb.Components.Card.card>

              <BoonWeb.Components.Card.card
                variant="bordered"
                color="warning"
                rounded="large"
                class="bg-black/20"
                padding="medium"
              >
                <p class="text-sm text-stone-400">Entries</p>

                <p class="mt-3 text-3xl font-semibold text-stone-50">{@shipment.entry_count}</p>
              </BoonWeb.Components.Card.card>

              <BoonWeb.Components.Card.card
                variant="bordered"
                color="dark"
                rounded="large"
                class="bg-black/20"
                padding="medium"
              >
                <p class="text-sm text-stone-400">Destination</p>

                <p class="mt-3 text-lg font-semibold text-stone-50">
                  {shipment_destination_label(@shipment)}
                </p>
              </BoonWeb.Components.Card.card>

              <BoonWeb.Components.Card.card
                variant="bordered"
                color="danger"
                rounded="large"
                class="bg-black/20"
                padding="medium"
              >
                <p class="text-sm text-stone-400">Submitted From</p>

                <p class="mt-3 text-lg font-semibold text-stone-50">
                  {@shipment.submitted_from || "-"}
                </p>
              </BoonWeb.Components.Card.card>
            </div>
          </BoonWeb.Components.Card.card_content>
        </BoonWeb.Components.Card.card>

        <BoonWeb.Components.Table.table
          id="shipment-entries-table"
          rows={@shipment.entries}
          row_id={fn entry -> "shipment-entry-#{entry.id}" end}
          variant="base_hoverable"
          rounded="large"
          class="text-stone-200"
        >
          <:col :let={entry} label="PO Number">
            <span class="font-semibold text-stone-50">PO {entry.po_number}</span>
          </:col>

          <:col :let={entry} label="Pallet Type">
            <span class="text-stone-400">{pallet_type_label(entry.pallet_type)}</span>
          </:col>

          <:col :let={entry} label="Pair">{entry.pair_number}</:col>

          <:col :let={entry} label="Tank Item">
            <span class="text-stone-400">{entry.tank_item_number}</span>
          </:col>

          <:col :let={entry} label="Cabinet Item">
            <span class="text-stone-400">{entry.cabinet_item_number}</span>
          </:col>
        </BoonWeb.Components.Table.table>
      </section>
    </Layouts.app>
    """
  end

  defp reprint_packing_slip(socket, {:ok, result}) do
    case result.status do
      :completed ->
        socket
        |> assign(:shipment, Operations.get_shipment!(socket.assigns.shipment.id))
        |> put_flash(:info, "Reprinted packing slip to #{result.target_printer}.")

      :skipped ->
        put_flash(socket, :error, result.error || "Packing slip reprint was skipped.")

      :failed ->
        put_flash(
          socket,
          :error,
          "Packing slip reprint failed: #{result.error || "Unknown error"}"
        )
    end
  end

  defp packing_slip_dispatch_options do
    printing_config = Application.get_env(:boon, :printing, [])

    [
      packing_slip_transport:
        Keyword.get(printing_config, :packing_slip_transport_module, PalletTagTransport),
      packing_slip_transport_opts: Keyword.get(printing_config, :packing_slip_transport_opts, [])
    ]
  end

  defp shipment_heading(shipment), do: "Shipment #{format_datetime(shipment.confirmed_at)}"

  defp shipment_destination_label(shipment) do
    shipment
    |> shipment_ship_to()
    |> ShippingLocation.label()
    |> case do
      nil -> "-"
      label -> label
    end
  end

  defp shipment_ship_to(%{entries: [%{purchase_order: %{ship_to: ship_to}} | _rest]}), do: ship_to
  defp shipment_ship_to(_shipment), do: nil

  defp pallet_type_label("tank"), do: "Tank"
  defp pallet_type_label("cabinet"), do: "Cabinet"
  defp pallet_type_label("bundle"), do: "Bundle"
  defp pallet_type_label(value), do: value

  defp format_datetime(%DateTime{} = datetime), do: Calendar.strftime(datetime, "%Y-%m-%d %H:%M")
  defp format_datetime(_datetime), do: "-"
end
