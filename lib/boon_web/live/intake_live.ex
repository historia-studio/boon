defmodule BoonWeb.IntakeLive do
  use BoonWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :current_scope, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} current_user={@current_user}>
      <section class="space-y-6 rounded-[2rem] border border-white/10 bg-white/5 p-8">
        <div class="space-y-3">
          <p class="text-sm uppercase tracking-[0.3em] text-amber-300">Intake</p>

          <h1 class="text-3xl font-semibold text-white">ZIP import staging area</h1>

          <p class="max-w-2xl text-sm leading-7 text-stone-300">
            Phase 2 will accept a work package number plus a ZIP of PDFs, then persist parsed POs and PO lines into the operations domain created in this slice.
          </p>
        </div>

        <div class="grid gap-4 md:grid-cols-2">
          <div class="rounded-3xl border border-dashed border-white/15 bg-stone-900/60 p-6 text-sm text-stone-400">
            Work package input, ZIP upload, and parse status will live here.
          </div>

          <div class="rounded-3xl border border-white/10 bg-stone-900/60 p-6 text-sm text-stone-400">
            Parse failures and import summary will surface here once the parser is implemented.
          </div>
        </div>
      </section>
    </Layouts.app>
    """
  end
end
