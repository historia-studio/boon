defmodule BoonWeb.WorkPackageLive.Index do
  use BoonWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :current_scope, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <section class="space-y-6 rounded-[2rem] border border-white/10 bg-white/5 p-8">
        <div class="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
          <div class="space-y-3">
            <p class="text-sm uppercase tracking-[0.3em] text-amber-300">Work Packages</p>
            
            <h1 class="text-3xl font-semibold text-white">Core operations records</h1>
            
            <p class="max-w-2xl text-sm leading-7 text-stone-300">
              Work packages now group purchase orders, and each purchase order can hold multiple PO lines. CRUD flows and review actions can be layered onto these resources next.
            </p>
          </div>
          
          <div class="rounded-full border border-white/10 bg-stone-900/80 px-4 py-2 text-sm text-stone-300">
            No work packages imported yet
          </div>
        </div>
        
        <div class="overflow-hidden rounded-3xl border border-white/10 bg-stone-900/60">
          <div class="grid grid-cols-[1.2fr_1fr_1fr] gap-4 border-b border-white/10 px-6 py-4 text-xs uppercase tracking-[0.25em] text-stone-500">
            <span>Work Package</span> <span>Purchase Orders</span> <span>PO Lines</span>
          </div>
          
          <div class="px-6 py-8 text-sm text-stone-400">
            Imported work packages will appear here once intake is wired up.
          </div>
        </div>
      </section>
    </Layouts.app>
    """
  end
end
