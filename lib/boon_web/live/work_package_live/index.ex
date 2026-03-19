defmodule BoonWeb.WorkPackageLive.Index do
  use BoonWeb, :live_view

  alias Boon.Operations

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_scope, nil)
     |> assign(:work_packages, Operations.list_work_packages())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <section class="space-y-6 rounded-[2rem] border border-white/10 bg-white/5 p-8">
        <div class="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
          <div class="space-y-3">
            <p class="text-sm uppercase tracking-[0.3em] text-amber-300">Work Packages</p>

            <h1 class="text-3xl font-semibold text-white">Captured intake records</h1>

            <p class="max-w-2xl text-sm leading-7 text-stone-300">
              Manual intake writes directly into the work package hierarchy. Review and printing can build on the exact same records once those steps are implemented.
            </p>
          </div>
           <.button navigate={~p"/intake"}>Enter Work Package</.button>
        </div>

        <div class="overflow-hidden rounded-3xl border border-white/10 bg-stone-900/60">
          <div class="grid grid-cols-[1.2fr_1fr_1fr_1fr] gap-4 border-b border-white/10 px-6 py-4 text-xs uppercase tracking-[0.25em] text-stone-500">
            <span>Work Package</span> <span>Purchase Orders</span> <span>PO Lines</span>
            <span>Entered</span>
          </div>

          <div :if={@work_packages == []} class="px-6 py-8 text-sm text-stone-400">
            No work packages have been entered yet.
          </div>

          <.link
            :for={work_package <- @work_packages}
            navigate={~p"/work-packages/#{work_package.id}"}
            class="grid grid-cols-[1.2fr_1fr_1fr_1fr] gap-4 border-b border-white/10 px-6 py-5 text-sm transition hover:bg-white/5"
          >
            <span class="font-semibold text-white">WP {work_package.number}</span>
            <span class="text-stone-300">{length(work_package.purchase_orders)}</span>
            <span class="text-stone-300">{line_count(work_package)}</span>
            <span class="text-stone-500">{format_datetime(work_package.inserted_at)}</span>
          </.link>
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

  defp format_datetime(%DateTime{} = datetime), do: Calendar.strftime(datetime, "%Y-%m-%d %H:%M")
  defp format_datetime(_datetime), do: "-"
end
