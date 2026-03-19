defmodule BoonWeb.ReviewLive do
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
          <p class="text-sm uppercase tracking-[0.3em] text-amber-300">Review</p>

          <h1 class="text-3xl font-semibold text-white">Purchase order validation before print</h1>

          <p class="max-w-2xl text-sm leading-7 text-stone-300">
            This screen will review imported work packages, correct shipping details, and launch print jobs. For now it provides the Phase 1 route and operator shell target.
          </p>
        </div>

        <div class="rounded-3xl border border-white/10 bg-stone-900/60 p-6">
          <p class="text-sm text-stone-400">
            Upcoming review data points: PO number, order date, revision date, reference, and the parsed PO lines associated with each work package.
          </p>
        </div>
      </section>
    </Layouts.app>
    """
  end
end
