defmodule BoonWeb.ShipLive do
  use BoonWeb, :live_view

  alias Boon.Operations

  @impl true
  def mount(params, _session, socket) do
    initial_token = Map.get(params, "tag")

    {initial_tokens, initial_errors} = initial_draft_state(initial_token)

    {:ok,
     socket
     |> assign(:current_scope, nil)
     |> assign(:draft_storage_key, draft_storage_key())
     |> assign(:staged_tokens, initial_tokens)
     |> assign(:staged_tags, [])
     |> assign(:draft_errors, initial_errors)
     |> assign(:shipment_summary, Operations.shipment_draft_summary([]))
     |> hydrate_draft(initial_tokens, initial_errors)}
  end

  @impl true
  def handle_event("hydrate_shipment_draft", %{"tokens" => tokens}, socket) do
    {:noreply, hydrate_draft(socket, normalize_tokens(tokens), [])}
  end

  def handle_event("remove_staged_tag", %{"token" => token}, socket) do
    remaining_tokens = Enum.reject(socket.assigns.staged_tokens, &(&1 == token))

    {:noreply,
     socket
     |> hydrate_draft(remaining_tokens, [])
     |> push_event("sync-shipment-draft", %{tokens: remaining_tokens})}
  end

  def handle_event("submit_shipment", _params, socket) do
    case Operations.create_shipment_from_tokens(socket.assigns.staged_tokens, %{
           submitted_from: shipping_host()
         }) do
      {:ok, shipment} ->
        {:noreply,
         socket
         |> assign(:staged_tokens, [])
         |> assign(:staged_tags, [])
         |> assign(:draft_errors, [])
         |> assign(:shipment_summary, Operations.shipment_draft_summary([]))
         |> put_flash(
           :info,
           "Shipment #{shipment.id} confirmed with #{shipment.entry_count} pallet tags."
         )
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
                  Scan a pallet-tag QR code to open this page on
                  <span class="font-semibold text-stone-100">{shipping_host()}</span>.
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
                  {length(@shipment_summary.purchase_orders)} purchase orders ·
                  {length(@shipment_summary.work_packages)} work packages
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

              <div class="mt-4 space-y-3">
                <div
                  :if={@staged_tags == []}
                  class="rounded-[1.5rem] border border-dashed border-white/10 px-4 py-6 text-sm text-stone-400"
                >
                  No pallet tags staged. Scan a QR or open this page with a tag query parameter.
                </div>

                <div
                  :for={tag <- @staged_tags}
                  id={"staged-tag-#{tag.pallet_tag_token}"}
                  class="app-panel-soft flex flex-col gap-3 rounded-[1.25rem] px-4 py-4 md:flex-row md:items-center md:justify-between"
                >
                  <div>
                    <p class="text-sm font-semibold text-stone-100">
                      WP {tag.work_package_number} · PO {tag.po_number} ·
                      {pallet_identity_label(tag)}
                    </p>
                    <p class="mt-1 text-sm text-stone-400">
                      Tank {tag.tank_item_number} / Cabinet {tag.cabinet_item_number}
                    </p>
                  </div>

                  <BoonWeb.Components.Button.button
                    id={"remove-staged-tag-#{tag.pallet_tag_token}"}
                    type="button"
                    variant="ghost"
                    color="warning"
                    size="small"
                    icon="hero-x-mark"
                    phx-click="remove_staged_tag"
                    phx-value-token={tag.pallet_tag_token}
                  >
                    Remove
                  </BoonWeb.Components.Button.button>
                </div>
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
    |> Keyword.get(:host, "DESKTOP-3BBMKIS")
  end

  defp pallet_identity_label(tag) do
    "#{pallet_type_label(tag.pallet_type)} #{tag.pair_number}"
  end

  defp pallet_type_label("tank"), do: "Tank"
  defp pallet_type_label("cabinet"), do: "Cabinet"
  defp pallet_type_label("bundle"), do: "Bundle"
  defp pallet_type_label(_other), do: "Pallet"
end
