defmodule BoonWeb.DashboardLive do
  use BoonWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_scope, nil)
     |> assign(:cards, cards())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_user={@current_user}>
      <section class="grid gap-8 lg:grid-cols-[1.2fr_0.8fr]">
        <div class="space-y-6 rounded-[2rem] border border-white/10 bg-white/5 p-8 shadow-2xl shadow-black/20">
          <div class="space-y-4">
            <p class="text-sm uppercase tracking-[0.3em] text-amber-300">Phase 1 Shell</p>

            <h1 class="max-w-2xl text-4xl font-semibold tracking-tight text-white">
              Build the operator workspace before intake, printing, and shipping logic lands.
            </h1>

            <p class="max-w-2xl text-base leading-7 text-stone-300">
              The data model is now anchored on work packages, purchase orders, and PO lines. The next implementation slices can layer import, review, and shipment behavior onto this shell.
            </p>
          </div>

          <div class="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
            <article
              :for={card <- @cards}
              class="rounded-3xl border border-white/10 bg-stone-900/70 p-5"
            >
              <p class="text-sm text-stone-400">{card.label}</p>

              <p class="mt-3 text-3xl font-semibold text-white">{card.value}</p>

              <p class="mt-2 text-sm text-stone-500">{card.detail}</p>
            </article>
          </div>
        </div>

        <aside class="space-y-4 rounded-[2rem] border border-amber-400/20 bg-amber-300/10 p-8">
          <p class="text-sm uppercase tracking-[0.3em] text-amber-200">Immediate Workflow</p>

          <ol class="space-y-4 text-sm text-stone-200">
            <li class="rounded-2xl border border-white/10 bg-black/20 p-4">
              1. Intake ZIP uploads into a work package.
            </li>

            <li class="rounded-2xl border border-white/10 bg-black/20 p-4">
              2. Review parsed POs and shipping details before print.
            </li>

            <li class="rounded-2xl border border-white/10 bg-black/20 p-4">
              3. Use the mobile-first ship screen for staged scans and confirmation.
            </li>
          </ol>
        </aside>
      </section>
    </Layouts.app>
    """
  end

  defp cards do
    [
      %{label: "Work Packages", value: "0", detail: "Core resource scaffolded"},
      %{label: "Purchase Orders", value: "0", detail: "Grouped under work packages"},
      %{label: "PO Lines", value: "0", detail: "Ready for parsed intake data"},
      %{label: "Shipping Screens", value: "1", detail: "Placeholder route in place"}
    ]
  end
end
