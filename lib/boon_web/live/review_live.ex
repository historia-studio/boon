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
      <section>
        <BoonWeb.Components.Card.card
          variant="gradient"
          color="danger"
          rounded="extra_large"
          class="app-panel"
          padding="large"
        >
          <BoonWeb.Components.Card.card_content space="large">
            <div class="space-y-3">
              <BoonWeb.Components.Badge.badge
                color="warning"
                variant="bordered"
                rounded="full"
                class="w-fit text-[0.68rem] font-medium uppercase tracking-[0.24em]"
              >
                Review
              </BoonWeb.Components.Badge.badge>

              <h1 class="text-3xl font-semibold text-stone-50">Purchase order review before print</h1>
            </div>
          </BoonWeb.Components.Card.card_content>
        </BoonWeb.Components.Card.card>
      </section>
    </Layouts.app>
    """
  end
end
