defmodule BoonWeb.WorkPackageLive.Show do
  use BoonWeb, :live_view

  alias Boon.Operations

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    work_package = Operations.get_work_package!(id)

    {:ok,
     socket
     |> assign(:current_scope, nil)
     |> assign(:work_package, work_package)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <section class="space-y-6 rounded-[2rem] border border-white/10 bg-white/5 p-8">
        <div class="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
          <div class="space-y-3">
            <p class="text-sm uppercase tracking-[0.3em] text-amber-300">Work Package</p>

            <h1 class="text-3xl font-semibold text-white">WP {@work_package.number}</h1>

            <p class="max-w-2xl text-sm leading-7 text-stone-300">
              This is the current intake shape: one work package with its purchase orders and PO lines ready for review, print, and later PDF-based import.
            </p>
          </div>

          <div class="flex flex-wrap gap-3">
            <.button navigate={~p"/intake"}>Enter Another</.button>
            <.button navigate={~p"/work-packages"}>All Work Packages</.button>
          </div>
        </div>

        <div class="grid gap-4 md:grid-cols-3">
          <article class="rounded-3xl border border-white/10 bg-stone-900/70 p-5">
            <p class="text-sm text-stone-400">Purchase Orders</p>

            <p class="mt-3 text-3xl font-semibold text-white">
              {length(@work_package.purchase_orders)}
            </p>
          </article>

          <article class="rounded-3xl border border-white/10 bg-stone-900/70 p-5">
            <p class="text-sm text-stone-400">PO Lines</p>

            <p class="mt-3 text-3xl font-semibold text-white">{line_count(@work_package)}</p>
          </article>

          <article class="rounded-3xl border border-white/10 bg-stone-900/70 p-5">
            <p class="text-sm text-stone-400">Status</p>

            <p class="mt-3 text-lg font-semibold text-white">Manual entry complete</p>
          </article>
        </div>

        <div class="space-y-4">
          <section
            :for={purchase_order <- @work_package.purchase_orders}
            id={"purchase-order-#{purchase_order.id}"}
            class="space-y-5 rounded-[2rem] border border-white/10 bg-stone-900/70 p-6"
          >
            <div class="grid gap-4 lg:grid-cols-[1.1fr_0.9fr] lg:items-start">
              <div>
                <p class="text-sm uppercase tracking-[0.25em] text-amber-300">Purchase Order</p>

                <h2 class="mt-2 text-2xl font-semibold text-white">{purchase_order.po_number}</h2>

                <p :if={purchase_order.reference} class="mt-2 text-sm text-stone-400">
                  {purchase_order.reference}
                </p>
              </div>

              <dl class="grid gap-3 sm:grid-cols-3">
                <div class="rounded-2xl border border-white/10 bg-black/20 p-4">
                  <dt class="text-xs uppercase tracking-[0.25em] text-stone-500">Order Date</dt>

                  <dd class="mt-2 text-sm text-white">{format_date(purchase_order.order_date)}</dd>
                </div>

                <div class="rounded-2xl border border-white/10 bg-black/20 p-4">
                  <dt class="text-xs uppercase tracking-[0.25em] text-stone-500">Revision Date</dt>

                  <dd class="mt-2 text-sm text-white">{format_date(purchase_order.revision_date)}</dd>
                </div>

                <div class="rounded-2xl border border-white/10 bg-black/20 p-4">
                  <dt class="text-xs uppercase tracking-[0.25em] text-stone-500">PO Lines</dt>

                  <dd class="mt-2 text-sm text-white">{length(purchase_order.lines)}</dd>
                </div>
              </dl>
            </div>

            <div class="overflow-hidden rounded-3xl border border-white/10 bg-black/20">
              <div class="grid grid-cols-[0.6fr_1.6fr_1fr_0.8fr] gap-4 border-b border-white/10 px-5 py-4 text-xs uppercase tracking-[0.25em] text-stone-500">
                <span>Line</span> <span>Item Number / Description</span> <span>Ship Date</span>
                <span>Quantity</span>
              </div>

              <div
                :for={line <- purchase_order.lines}
                id={"purchase-order-line-#{line.id}"}
                class="grid grid-cols-[0.6fr_1.6fr_1fr_0.8fr] gap-4 border-b border-white/10 px-5 py-4 text-sm"
              >
                <span class="font-semibold text-white">{line.line}</span>
                <span class="text-stone-300">{line.item_number}</span>
                <span class="text-stone-400">{format_date(line.ship_date)}</span>
                <span class="text-stone-300">{line.quantity}</span>
              </div>
            </div>
          </section>
        </div>
      </section>
    </Layouts.app>
    """
  end

  defp line_count(work_package) do
    Enum.reduce(work_package.purchase_orders, 0, fn purchase_order, total ->
      total + length(purchase_order.lines)
    end)
  end

  defp format_date(%Date{} = date), do: Calendar.strftime(date, "%Y-%m-%d")
  defp format_date(_date), do: "-"
end
