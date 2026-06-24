defmodule BoonWeb.ShipmentLive.Index do
  use BoonWeb, :live_view

  alias Boon.Operations
  alias Boon.ShippingLocation

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_scope, nil)
     |> assign(:shipments, Operations.list_shipments())}
  end

  @impl true
  def handle_event("delete_shipment", %{"id" => id}, socket) do
    case Operations.delete_shipment(id) do
      :ok ->
        {:noreply,
         socket
         |> assign(:shipments, Operations.list_shipments())
         |> put_flash(:info, "Shipment deleted.")}

      {:error, [message | _rest]} ->
        {:noreply, put_flash(socket, :error, message)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_user={@current_user}>
      <BoonWeb.Components.Card.card
        variant="bordered"
        color="danger"
        rounded="extra_large"
        class="app-panel"
        padding="large"
      >
        <BoonWeb.Components.Card.card_content space="large">
          <div class="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
            <div class="space-y-3">
              <BoonWeb.Components.Badge.badge
                color="warning"
                variant="bordered"
                rounded="full"
                class="w-fit text-[0.68rem] font-medium uppercase tracking-[0.24em]"
              >
                Shipments
              </BoonWeb.Components.Badge.badge>

              <h1 class="text-3xl font-semibold text-stone-50">Confirmed shipment history</h1>
            </div>

            <div class="flex flex-wrap gap-3">
              <BoonWeb.Components.Button.button_link
                navigate={~p"/ship"}
                variant="shadow"
                color="danger"
                icon="hero-qr-code"
                size="medium"
              >
                Open Shipping
              </BoonWeb.Components.Button.button_link>
              <BoonWeb.Components.Button.button_link
                navigate={~p"/work-packages"}
                variant="outline"
                color="warning"
                size="medium"
              >
                Work Packages
              </BoonWeb.Components.Button.button_link>
            </div>
          </div>

          <div
            :if={@shipments == []}
            class="rounded-[1.5rem] border border-dashed border-white/10 px-6 py-8 text-sm text-stone-400"
          >
            No shipments have been confirmed yet.
          </div>

          <BoonWeb.Components.Table.table
            :if={@shipments != []}
            id="shipments-table"
            rows={@shipments}
            row_id={fn shipment -> "shipment-#{shipment.id}" end}
            row_click={fn shipment -> JS.navigate(~p"/shipments/#{shipment.id}") end}
            variant="base_hoverable"
            rounded="large"
            class="text-stone-200"
          >
            <:col :let={shipment} label="Confirmed">
              <span class="font-semibold text-stone-50">
                {format_datetime(shipment.confirmed_at)}
              </span>
            </:col>

            <:col :let={shipment} label="Work Packages">
              <span class="text-stone-400">{shipment_work_package_summary(shipment)}</span>
            </:col>

            <:col :let={shipment} label="Destination">{shipment_destination_label(shipment)}</:col>

            <:col :let={shipment} label="Entries">{shipment.entry_count}</:col>

            <:col :let={shipment} label="Submitted From">
              <span class="text-stone-400">{shipment.submitted_from || "-"}</span>
            </:col>

            <:action :let={shipment}>
              <div class="flex gap-2">
                <BoonWeb.Components.Button.button_link
                  navigate={~p"/shipments/#{shipment.id}"}
                  variant="subtle"
                  color="warning"
                  size="extra_small"
                >
                  Open
                </BoonWeb.Components.Button.button_link>

                <BoonWeb.Components.Button.button
                  id={"delete-shipment-#{shipment.id}"}
                  type="button"
                  variant="outline"
                  color="danger"
                  size="extra_small"
                  icon="hero-trash"
                  phx-click="delete_shipment"
                  phx-value-id={shipment.id}
                >
                  Delete
                </BoonWeb.Components.Button.button>
              </div>
            </:action>
          </BoonWeb.Components.Table.table>
        </BoonWeb.Components.Card.card_content>
      </BoonWeb.Components.Card.card>
    </Layouts.app>
    """
  end

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

  defp shipment_work_package_summary(shipment) do
    shipment
    |> shipment_work_packages()
    |> Enum.map(&"WP #{&1.number}")
    |> Enum.join(", ")
    |> case do
      "" -> "-"
      summary -> summary
    end
  end

  defp shipment_work_packages(shipment) do
    shipment
    |> Map.get(:entries, [])
    |> Enum.map(&Map.get(&1, :work_package))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq_by(& &1.id)
    |> Enum.sort_by(& &1.number)
  end

  defp format_datetime(%DateTime{} = datetime), do: Calendar.strftime(datetime, "%Y-%m-%d %H:%M")
  defp format_datetime(_datetime), do: "-"
end
