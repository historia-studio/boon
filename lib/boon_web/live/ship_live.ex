defmodule BoonWeb.ShipLive do
  use BoonWeb, :live_view

  alias Boon.Operations
  alias Boon.Printing.{Dispatcher, PalletTagTransport}

  @impl true
  def mount(params, _session, socket) do
    initial_token = Map.get(params, "tag")

    {initial_tokens, initial_errors} = initial_draft_state(initial_token)
    po_filter = ""

    {:ok,
     socket
     |> assign(:current_scope, nil)
     |> assign(:draft_storage_key, draft_storage_key())
     |> assign(:po_filter, po_filter)
     |> assign(:po_filter_form, po_filter_form(po_filter))
     |> assign(:available_tags, [])
     |> assign(:staged_tokens, initial_tokens)
     |> assign(:staged_tags, [])
     |> assign(:draft_errors, initial_errors)
     |> assign(:shipment_summary, Operations.shipment_draft_summary([]))
     |> hydrate_draft(initial_tokens, initial_errors)}
  end

  @impl true
  def handle_event("hydrate_shipment_draft", %{"tokens" => tokens}, socket) do
    {:noreply,
     socket
     |> hydrate_draft(normalize_tokens(tokens), [])
     |> assign_available_tags(socket.assigns.po_filter)}
  end

  def handle_event("filter_available_tags", %{"filter" => %{"po_number" => po_number}}, socket) do
    normalized_po_number = normalize_po_filter(po_number)

    {:noreply,
     socket
     |> assign(:po_filter, normalized_po_number)
     |> assign(:po_filter_form, po_filter_form(normalized_po_number))
     |> assign_available_tags(normalized_po_number)}
  end

  def handle_event("add_staged_tag", %{"token" => token}, socket) do
    next_tokens = normalize_tokens(socket.assigns.staged_tokens ++ [token])

    {:noreply,
     socket
     |> hydrate_draft(next_tokens, [])
     |> assign_available_tags(socket.assigns.po_filter)
     |> push_event("sync-shipment-draft", %{tokens: next_tokens})}
  end

  def handle_event("remove_staged_tag", %{"token" => token}, socket) do
    remaining_tokens = Enum.reject(socket.assigns.staged_tokens, &(&1 == token))

    {:noreply,
     socket
     |> hydrate_draft(remaining_tokens, [])
     |> assign_available_tags(socket.assigns.po_filter)
     |> push_event("sync-shipment-draft", %{tokens: remaining_tokens})}
  end

  def handle_event("submit_shipment", _params, socket) do
    case Operations.create_shipment_from_tokens(socket.assigns.staged_tokens, %{
           submitted_from: shipping_host()
         }) do
      {:ok, shipment} ->
        {:ok, packing_slip_result} =
          Dispatcher.dispatch_shipment_packing_slip(shipment, packing_slip_dispatch_options())

        {:noreply,
         socket
         |> assign(:staged_tokens, [])
         |> assign(:staged_tags, [])
         |> assign(:draft_errors, [])
         |> assign(:shipment_summary, Operations.shipment_draft_summary([]))
         |> assign_available_tags(socket.assigns.po_filter)
         |> put_flash(:info, shipment_flash_message(shipment, packing_slip_result))
         |> maybe_put_packing_slip_error(packing_slip_result)
         |> push_event("clear-shipment-draft", %{storageKey: socket.assigns.draft_storage_key})}

      {:error, errors} when is_list(errors) ->
        {:noreply, assign(socket, :draft_errors, errors)}

      {:error, error} ->
        {:noreply, assign(socket, :draft_errors, [error])}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <section>
        <BoonWeb.Components.Card.card
          variant="gradient"
          color="danger"
          rounded="extra_large"
          class="app-panel"
          padding="large"
        >
          <BoonWeb.Components.Card.card_content space="large">
            <div
              id="shipping-draft-hook"
              phx-hook=".ShippingDraft"
              data-storage-key={@draft_storage_key}
              data-initial-tokens={Jason.encode!(@staged_tokens)}
            />

            <div class="space-y-3">
              <BoonWeb.Components.Badge.badge
                color="warning"
                variant="bordered"
                rounded="full"
                class="w-fit text-[0.68rem] font-medium uppercase tracking-[0.24em]"
              >
                Ship
              </BoonWeb.Components.Badge.badge>

              <h1 class="text-3xl font-semibold text-stone-50">Scan and ship</h1>
            </div>

            <div class="grid gap-4 md:grid-cols-3">
              <BoonWeb.Components.Card.card
                variant="bordered"
                color="warning"
                rounded="large"
                class="bg-black/15"
                padding="medium"
              >
                <p class="app-kicker text-[0.68rem]">Entry</p>
                <p class="mt-3 text-sm text-stone-300">
                  Scan a pallet-tag QR code to open this page on <span class="font-semibold text-stone-100">{shipping_host()}</span>.
                </p>
              </BoonWeb.Components.Card.card>

              <BoonWeb.Components.Card.card
                variant="bordered"
                color="warning"
                rounded="large"
                class="bg-black/15"
                padding="medium"
              >
                <p class="app-kicker text-[0.68rem]">Draft</p>
                <p class="mt-3 text-3xl font-semibold text-stone-50">
                  {@shipment_summary.staged_tags}
                </p>
                <p class="mt-2 text-sm text-stone-300">
                  {length(@shipment_summary.purchase_orders)} purchase orders · {length(
                    @shipment_summary.work_packages
                  )} work packages
                </p>
              </BoonWeb.Components.Card.card>

              <BoonWeb.Components.Card.card
                variant="bordered"
                color="danger"
                rounded="large"
                class="bg-black/15"
                padding="medium"
              >
                <p class="app-kicker text-[0.68rem]">Submit</p>
                <div class="mt-3">
                  <BoonWeb.Components.Button.button
                    id="submit-shipment"
                    type="button"
                    variant="shadow"
                    color="danger"
                    icon="hero-truck"
                    size="medium"
                    phx-click="submit_shipment"
                    disabled={@staged_tags == []}
                    class={if(@staged_tags == [], do: "cursor-not-allowed opacity-40")}
                  >
                    Confirm Shipment
                  </BoonWeb.Components.Button.button>
                </div>
              </BoonWeb.Components.Card.card>
            </div>

            <BoonWeb.Components.Card.card
              variant="bordered"
              color="warning"
              rounded="large"
              class="bg-black/15"
              padding="medium"
            >
              <p class="app-kicker text-[0.68rem]">Add By PO</p>

              <.form
                for={@po_filter_form}
                id="shipment-po-filter-form"
                phx-change="filter_available_tags"
              >
                <.input
                  field={@po_filter_form[:po_number]}
                  type="text"
                  label="PO number"
                  placeholder="Search purchase orders"
                  autocomplete="off"
                />
              </.form>

              <div class="mt-4">
                <div
                  :if={@po_filter != "" and @available_tags == []}
                  class="rounded-[1.5rem] border border-dashed border-white/10 px-4 py-6 text-sm text-stone-400"
                >
                  No available pallet tags match that PO number.
                </div>

                <div
                  :if={@po_filter == ""}
                  class="rounded-[1.5rem] border border-dashed border-white/10 px-4 py-6 text-sm text-stone-400"
                >
                  Enter a PO number to find pallet tags you can add manually.
                </div>

                <BoonWeb.Components.Table.table
                  :if={@available_tags != []}
                  id="available-tags-table"
                  rows={@available_tags}
                  row_id={&available_tag_row_id/1}
                  row_click={
                    fn tag -> JS.push("add_staged_tag", value: %{token: tag.pallet_tag_token}) end
                  }
                  variant="base_hoverable"
                  rounded="large"
                  class="text-stone-200"
                >
                  <:col :let={tag} label="PO Number">
                    <span class="font-semibold text-stone-50">PO {tag.po_number}</span>
                  </:col>

                  <:col :let={tag} label="Work Package">
                    <span class="text-stone-400">WP {tag.work_package_number}</span>
                  </:col>

                  <:col :let={tag} label="Pallet">
                    <span class="text-stone-400">{pallet_identity_label(tag)}</span>
                  </:col>

                  <:col :let={tag} label="Items">
                    <span class="text-stone-400">{pallet_item_label(tag)}</span>
                  </:col>
                </BoonWeb.Components.Table.table>
              </div>
            </BoonWeb.Components.Card.card>

            <BoonWeb.Components.Card.card
              :if={@draft_errors != []}
              variant="bordered"
              color="danger"
              rounded="large"
              class="bg-black/15"
              padding="medium"
            >
              <p class="app-kicker text-[0.68rem]">Errors</p>
              <ul class="mt-3 space-y-2 text-sm text-rose-100">
                <li :for={error <- @draft_errors}>{error}</li>
              </ul>
            </BoonWeb.Components.Card.card>

            <BoonWeb.Components.Card.card
              variant="bordered"
              color="warning"
              rounded="large"
              class="bg-black/15"
              padding="medium"
            >
              <p class="app-kicker text-[0.68rem]">Staged Pallet Tags</p>

              <div class="mt-4">
                <div
                  :if={@staged_tags == []}
                  class="rounded-[1.5rem] border border-dashed border-white/10 px-4 py-6 text-sm text-stone-400"
                >
                  No pallet tags staged. Scan a QR or open this page with a tag query parameter.
                </div>

                <BoonWeb.Components.Table.table
                  :if={@staged_tags != []}
                  id="staged-tags-table"
                  rows={@staged_tags}
                  row_id={&staged_tag_row_id/1}
                  variant="base_hoverable"
                  rounded="large"
                  class="text-stone-200"
                >
                  <:col :let={tag} label="Work Package / PO">
                    <span class="font-semibold text-stone-50">
                      WP {tag.work_package_number} · PO {tag.po_number} · {pallet_identity_label(tag)}
                    </span>
                  </:col>

                  <:col :let={tag} label="Items">
                    <span class="text-stone-400">{pallet_item_label(tag)}</span>
                  </:col>

                  <:action :let={tag}>
                    <BoonWeb.Components.Button.button
                      id={remove_staged_tag_button_id(tag)}
                      type="button"
                      variant="shadow"
                      color="warning"
                      size="medium"
                      icon="hero-x-mark"
                      title="Remove pallet tag"
                      aria-label="Remove pallet tag"
                      phx-click="remove_staged_tag"
                      phx-value-token={tag.pallet_tag_token}
                    >
                      Remove
                    </BoonWeb.Components.Button.button>
                  </:action>
                </BoonWeb.Components.Table.table>
              </div>
            </BoonWeb.Components.Card.card>

            <script :type={Phoenix.LiveView.ColocatedHook} name=".ShippingDraft">
              export default {
                mounted() {
                  this.storageKey = this.el.dataset.storageKey
                  this.initialTokens = this.parseTokens(this.el.dataset.initialTokens)
                  const storedTokens = this.readDraft()
                  const mergedTokens = [...new Set([...storedTokens, ...this.initialTokens])]

                  this.writeDraft(mergedTokens)
                  this.pushEvent("hydrate_shipment_draft", {tokens: mergedTokens})

                  this.handleEvent("sync-shipment-draft", ({tokens}) => {
                    this.writeDraft(tokens || [])
                  })

                  this.handleEvent("clear-shipment-draft", () => {
                    window.localStorage.removeItem(this.storageKey)
                  })
                },

                parseTokens(encodedTokens) {
                  try {
                    const parsed = JSON.parse(encodedTokens || "[]")
                    return Array.isArray(parsed) ? parsed.filter(token => typeof token === "string") : []
                  } catch {
                    return []
                  }
                },

                readDraft() {
                  try {
                    const parsed = JSON.parse(window.localStorage.getItem(this.storageKey) || "[]")
                    return Array.isArray(parsed) ? parsed.filter(token => typeof token === "string") : []
                  } catch {
                    return []
                  }
                },

                writeDraft(tokens) {
                  window.localStorage.setItem(this.storageKey, JSON.stringify(tokens))
                }
              }
            </script>
          </BoonWeb.Components.Card.card_content>
        </BoonWeb.Components.Card.card>
      </section>
    </Layouts.app>
    """
  end

  defp hydrate_draft(socket, tokens, existing_errors) do
    {:ok, %{tags: tags, errors: resolve_errors}} = Operations.resolve_shipping_tokens(tokens)

    socket
    |> assign(:staged_tokens, Enum.map(tags, & &1.pallet_tag_token))
    |> assign(:staged_tags, tags)
    |> assign(:draft_errors, existing_errors ++ resolve_errors)
    |> assign(:shipment_summary, Operations.shipment_draft_summary(tags))
  end

  defp normalize_tokens(tokens) do
    tokens
    |> Enum.filter(&is_binary/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  defp normalize_po_filter(po_number) do
    po_number
    |> to_string()
    |> String.trim()
  end

  defp po_filter_form(po_number) do
    to_form(%{"po_number" => po_number}, as: :filter)
  end

  defp assign_available_tags(socket, po_number) do
    available_tags =
      po_number
      |> Operations.list_shipping_candidates_by_po()
      |> Enum.reject(&(&1.pallet_tag_token in socket.assigns.staged_tokens))

    assign(socket, :available_tags, available_tags)
  end

  defp initial_draft_state(nil), do: {[], []}

  defp initial_draft_state(initial_token) do
    case Operations.resolve_shipping_token(initial_token) do
      {:ok, _tag} -> {[initial_token], []}
      {:error, error} -> {[], [error]}
    end
  end

  defp draft_storage_key do
    Application.get_env(:boon, :shipping, [])
    |> Keyword.get(:draft_storage_key, "boon-shipment-draft-v1")
  end

  defp shipping_host do
    Application.get_env(:boon, :shipping, [])
    |> Keyword.get(:host, "BOON")
  end

  defp packing_slip_dispatch_options do
    printing_config = Application.get_env(:boon, :printing, [])

    [
      packing_slip_transport:
        Keyword.get(
          printing_config,
          :packing_slip_transport_module,
          Keyword.get(printing_config, :pallet_tag_transport_module, PalletTagTransport)
        ),
      packing_slip_transport_opts:
        Keyword.get(
          printing_config,
          :packing_slip_transport_opts,
          Keyword.get(printing_config, :pallet_tag_transport_opts, [])
        )
    ]
  end

  defp shipment_flash_message(shipment, %{status: :completed, target_printer: printer})
       when is_binary(printer) do
    "Shipment #{shipment.id} confirmed with #{shipment.entry_count} pallet tags. Printed packing slip to #{printer}."
  end

  defp shipment_flash_message(shipment, _packing_slip_result) do
    "Shipment #{shipment.id} confirmed with #{shipment.entry_count} pallet tags."
  end

  defp maybe_put_packing_slip_error(socket, %{status: :failed, error: error})
       when is_binary(error) do
    put_flash(
      socket,
      :error,
      "Packing slip printing failed after shipment confirmation: #{error}"
    )
  end

  defp maybe_put_packing_slip_error(socket, _result), do: socket

  defp pallet_identity_label(tag) do
    "#{pallet_type_label(tag.pallet_type)} #{tag.pair_number}"
  end

  defp pallet_item_label(tag) do
    [
      present_item_label("Tank", tag.tank_item_number),
      present_item_label("Cabinet", tag.cabinet_item_number)
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.join(" / ")
  end

  defp present_item_label(_label, item_number) when item_number in [nil, ""], do: nil
  defp present_item_label(label, item_number), do: "#{label} #{item_number}"

  defp available_tag_row_id(tag) do
    "available-tag-#{tag.purchase_order_id}-#{tag.pair_number}-#{tag.pallet_type}"
  end

  defp staged_tag_row_id(tag) do
    "staged-tag-#{tag.purchase_order_id}-#{tag.pair_number}-#{tag.pallet_type}"
  end

  defp remove_staged_tag_button_id(tag) do
    "remove-staged-tag-#{tag.purchase_order_id}-#{tag.pair_number}-#{tag.pallet_type}"
  end

  defp pallet_type_label("tank"), do: "Tank"
  defp pallet_type_label("cabinet"), do: "Cabinet"
  defp pallet_type_label("bundle"), do: "Bundle"
  defp pallet_type_label(_other), do: "Pallet"
end
