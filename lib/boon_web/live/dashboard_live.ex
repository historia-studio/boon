defmodule BoonWeb.DashboardLive do
  use BoonWeb, :live_view

  alias Boon.Operations

  @impl true
  def mount(_params, _session, socket) do
    work_packages = Operations.list_work_packages()
    counts = Operations.dashboard_counts()

    {:ok,
     socket
     |> assign(:current_scope, nil)
     |> assign(:cards, cards(counts))
     |> assign(:recent_work_packages, Enum.take(work_packages, 3))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <section class="grid gap-8 lg:grid-cols-[1.2fr_0.8fr]">
        <div class="space-y-6 rounded-[2rem] border border-white/10 bg-white/5 p-8 shadow-2xl shadow-black/20">
          <div class="space-y-4">
            <p class="text-sm uppercase tracking-[0.3em] text-amber-300">Data Entry Phase</p>

            <h1 class="max-w-2xl text-4xl font-semibold tracking-tight text-white">
              Capture work packages by hand now so intake, review, and printing have clean records to build on.
            </h1>

            <p class="max-w-2xl text-base leading-7 text-stone-300">
              The current slice lets operators key in a work package with multiple purchase orders and PO lines. PDF parsing can land later against the same workflow once the manual path feels right.
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

          <div class="rounded-3xl border border-white/10 bg-stone-900/70 p-6">
            <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
              <div>
                <p class="text-sm uppercase tracking-[0.25em] text-stone-500">Recent Work Packages</p>

                <p class="mt-2 text-sm text-stone-300">
                  Manual intake entries appear here first and then flow into review and print later.
                </p>
              </div>
               <.button navigate={~p"/intake"}>Enter New Work Package</.button>
            </div>

            <div
              :if={@recent_work_packages == []}
              class="mt-5 rounded-2xl border border-dashed border-white/10 px-4 py-6 text-sm text-stone-400"
            >
              No work packages have been entered yet.
            </div>

            <div :if={@recent_work_packages != []} class="mt-5 grid gap-3">
              <.link
                :for={work_package <- @recent_work_packages}
                navigate={~p"/work-packages/#{work_package.id}"}
                class="flex items-center justify-between rounded-2xl border border-white/10 bg-black/20 px-4 py-4 transition hover:border-amber-400/30 hover:bg-black/30"
              >
                <div>
                  <p class="text-sm font-semibold text-white">WP {work_package.number}</p>

                  <p class="mt-1 text-sm text-stone-400">
                    {length(work_package.purchase_orders)} purchase orders, {line_count(work_package)} PO lines
                  </p>
                </div>
                 <.icon name="hero-arrow-right" class="h-5 w-5 text-stone-500" />
              </.link>
            </div>
          </div>
        </div>

        <aside class="space-y-4 rounded-[2rem] border border-amber-400/20 bg-amber-300/10 p-8">
          <p class="text-sm uppercase tracking-[0.3em] text-amber-200">Immediate Workflow</p>

          <ol class="space-y-4 text-sm text-stone-200">
            <li class="rounded-2xl border border-white/10 bg-black/20 p-4">
              1. Enter a work package and its purchase orders by hand.
            </li>

            <li class="rounded-2xl border border-white/10 bg-black/20 p-4">
              2. Review the captured PO data before print routing exists.
            </li>

            <li class="rounded-2xl border border-white/10 bg-black/20 p-4">
              3. Reuse the same records when PDF import replaces manual entry.
            </li>
          </ol>

          <div class="rounded-2xl border border-white/10 bg-black/20 p-4 text-sm text-stone-300">
            The `reference/wp10` PDF set is in the repo as a variability sample for the next parser slice.
          </div>
        </aside>
      </section>
    </Layouts.app>
    """
  end

  defp cards(counts) do
    [
      %{
        label: "Work Packages",
        value: counts.work_packages,
        detail: "Entered into the operator workflow"
      },
      %{
        label: "Purchase Orders",
        value: counts.purchase_orders,
        detail: "Captured under work packages"
      },
      %{
        label: "PO Lines",
        value: counts.purchase_order_lines,
        detail: "Ready for review and print"
      },
      %{label: "Data Entry", value: "Live", detail: "Manual intake is available now"}
    ]
  end

  defp line_count(work_package) do
    Enum.reduce(work_package.purchase_orders, 0, fn purchase_order, total ->
      total + length(purchase_order.lines)
    end)
  end
end
