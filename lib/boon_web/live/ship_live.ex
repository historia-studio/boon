defmodule BoonWeb.ShipLive do
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
        <div class="space-y-3">
          <p class="text-sm uppercase tracking-[0.3em] text-amber-300">Ship</p>
          
          <h1 class="text-3xl font-semibold text-white">Mobile-first scan and ship workflow</h1>
          
          <p class="max-w-2xl text-sm leading-7 text-stone-300">
            Phase 4 will attach a camera scanning hook to this route, maintain a staged scan list, and require an explicit shipment confirmation.
          </p>
        </div>
        
        <div class="grid gap-4 md:grid-cols-3">
          <div class="rounded-3xl border border-white/10 bg-stone-900/60 p-5 text-sm text-stone-400">
            Scan target area
          </div>
          
          <div class="rounded-3xl border border-white/10 bg-stone-900/60 p-5 text-sm text-stone-400">
            Staged shipment list
          </div>
          
          <div class="rounded-3xl border border-white/10 bg-stone-900/60 p-5 text-sm text-stone-400">
            Confirmation summary
          </div>
        </div>
      </section>
    </Layouts.app>
    """
  end
end
