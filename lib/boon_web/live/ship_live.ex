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
      <section class="space-y-6 rounded-[2rem] border border-white/10 bg-white/5 p-8">
        <div
          id="shipping-draft-hook"
          phx-hook=".ShippingDraft"
          data-storage-key={@draft_storage_key}
          data-initial-tokens={Jason.encode!(@staged_tokens)}
        />

        <div class="space-y-3">
          <p class="text-sm uppercase tracking-[0.3em] text-amber-300">Ship</p>

          <h1 class="text-3xl font-semibold text-white">Mobile-first scan and ship workflow</h1>

          <p class="max-w-2xl text-sm leading-7 text-stone-300">
            Scan a pallet-tag QR directly into this route or keep this screen open and stage scans into the local draft. Draft shipment state stays in the browser until you confirm it.
          </p>
        </div>

        <div class="grid gap-4 md:grid-cols-3">
          <div class="rounded-3xl border border-white/10 bg-stone-900/60 p-5 text-sm text-stone-400">
            <p class="text-xs uppercase tracking-[0.24em] text-stone-500">Entry</p>
            <p class="mt-3 text-sm leading-7 text-stone-300">
              Use the pallet-tag QR to open this page on <span class="font-semibold text-stone-100">{shipping_host()}</span>. In-page camera scanning can be added on top of the same local draft model next.
            </p>
          </div>

          <div class="rounded-3xl border border-white/10 bg-stone-900/60 p-5 text-sm text-stone-400">
            <p class="text-xs uppercase tracking-[0.24em] text-stone-500">Draft</p>
            <p class="mt-3 text-3xl font-semibold text-stone-50">{@shipment_summary.staged_pairs}</p>
            <p class="mt-2 text-sm text-stone-300">
              {length(@shipment_summary.purchase_orders)} purchase orders staged across {length(
                @shipment_summary.work_packages
              )} work packages.
            </p>
          </div>

          <div class="rounded-3xl border border-white/10 bg-stone-900/60 p-5 text-sm text-stone-400">
            <p class="text-xs uppercase tracking-[0.24em] text-stone-500">Submit</p>
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
            <p class="mt-3 text-sm leading-7 text-stone-300">
              Confirmation persists a shipment record and clears the browser draft.
            </p>
          </div>
        </div>

        <div :if={@draft_errors != []} class="rounded-3xl border border-red-400/30 bg-red-950/40 p-5">
          <p class="text-xs uppercase tracking-[0.24em] text-red-200">Draft errors</p>
          <ul class="mt-3 space-y-2 text-sm text-red-100">
            <li :for={error <- @draft_errors}>{error}</li>
          </ul>
        </div>

        <div class="rounded-3xl border border-white/10 bg-stone-900/60 p-5">
          <div class="flex items-center justify-between gap-4">
            <div>
              <p class="text-xs uppercase tracking-[0.24em] text-stone-500">Staged pallet tags</p>
              <p class="mt-2 text-sm text-stone-300">
                Only tank and cabinet pallet-tag pairs count toward shipment completion.
              </p>
            </div>
          </div>

          <div class="mt-4 space-y-3">
            <div
              :if={@staged_tags == []}
              class="rounded-2xl border border-dashed border-white/10 p-5 text-sm text-stone-500"
            >
              No pallet tags are staged yet. Scan a QR or open this page with a `tag` query parameter.
            </div>

            <div
              :for={tag <- @staged_tags}
              id={"staged-tag-#{tag.pallet_tag_token}"}
              class="flex flex-col gap-3 rounded-[1.25rem] border border-white/10 bg-black/20 px-4 py-4 md:flex-row md:items-center md:justify-between"
            >
              <div>
                <p class="text-sm font-semibold text-stone-100">
                  WP {tag.work_package_number} · PO {tag.po_number} · Pair {tag.pair_number}
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
        </div>

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
end
