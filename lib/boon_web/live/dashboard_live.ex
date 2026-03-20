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
      <section class="space-y-8">
        <BoonWeb.Components.Card.card
          variant="gradient"
          color="danger"
          rounded="extra_large"
          class="app-panel"
          padding="large"
        >
          <BoonWeb.Components.Card.card_content space="large">
            <div class="space-y-5">
              <BoonWeb.Components.Badge.badge
                color="warning"
                variant="bordered"
                rounded="full"
                class="w-fit text-[0.68rem] font-medium uppercase tracking-[0.24em]"
              >
                Data Entry Phase
              </BoonWeb.Components.Badge.badge>

              <h1 class="max-w-3xl text-4xl font-semibold tracking-tight text-stone-50 sm:text-5xl">
                Work packages, purchase orders, and print — one flow.
              </h1>

              <div class="flex flex-wrap gap-3">
                <BoonWeb.Components.Button.button_link
                  navigate={~p"/intake"}
                  variant="shadow"
                  color="danger"
                  icon="hero-plus"
                  size="medium"
                >
                  Enter New Work Package
                </BoonWeb.Components.Button.button_link>
                <BoonWeb.Components.Button.button_link
                  navigate={~p"/work-packages"}
                  variant="outline"
                  color="warning"
                  size="medium"
                >
                  Browse Records
                </BoonWeb.Components.Button.button_link>
              </div>
            </div>

            <div class="grid gap-4 sm:grid-cols-3">
              <BoonWeb.Components.Card.card
                :for={card <- @cards}
                variant="bordered"
                color={card.color}
                rounded="large"
                class="bg-black/20 backdrop-blur-sm"
                padding="medium"
              >
                <p class="text-sm text-stone-400">{card.label}</p>
                <p class="mt-3 text-3xl font-semibold text-stone-50">{card.value}</p>
                <p class="mt-2 text-sm text-stone-500">{card.detail}</p>
              </BoonWeb.Components.Card.card>
            </div>

            <BoonWeb.Components.Card.card
              variant="bordered"
              color="warning"
              rounded="large"
              class="bg-black/20"
              padding="medium"
            >
              <BoonWeb.Components.Card.card_title class="items-start justify-between gap-4">
                <div>
                  <p class="app-kicker text-[0.68rem]">Recent Work Packages</p>
                </div>

                <BoonWeb.Components.Button.button_link
                  navigate={~p"/intake"}
                  variant="subtle"
                  color="warning"
                  size="small"
                >
                  Open Intake
                </BoonWeb.Components.Button.button_link>
              </BoonWeb.Components.Card.card_title>

              <BoonWeb.Components.Card.card_content class="mt-5">
                <div
                  :if={@recent_work_packages == []}
                  class="rounded-[1.25rem] border border-dashed border-white/10 px-4 py-6 text-sm text-stone-400"
                >
                  No work packages have been entered yet.
                </div>

                <div :if={@recent_work_packages != []} class="grid gap-3">
                  <.link
                    :for={work_package <- @recent_work_packages}
                    navigate={~p"/work-packages/#{work_package.id}"}
                    class="app-panel-soft flex items-center justify-between rounded-[1.25rem] px-4 py-4 transition hover:border-amber-300/20 hover:bg-white/5"
                  >
                    <div>
                      <p class="text-sm font-semibold text-stone-100">WP {work_package.number}</p>
                      <p class="mt-1 text-sm text-stone-400">
                        {length(work_package.purchase_orders)} purchase orders, {line_count(
                          work_package
                        )} PO lines
                      </p>
                    </div>
                    <.icon name="hero-arrow-right" class="h-5 w-5 text-stone-500" />
                  </.link>
                </div>
              </BoonWeb.Components.Card.card_content>
            </BoonWeb.Components.Card.card>
          </BoonWeb.Components.Card.card_content>
        </BoonWeb.Components.Card.card>
      </section>
    </Layouts.app>
    """
  end

  defp cards(counts) do
    [
      %{
        label: "Work Packages",
        value: counts.work_packages,
        detail: "Entered into the operator workflow",
        color: "danger"
      },
      %{
        label: "Purchase Orders",
        value: counts.purchase_orders,
        detail: "Captured under work packages",
        color: "warning"
      },
      %{
        label: "PO Lines",
        value: counts.purchase_order_lines,
        detail: "Reviewed in intake and ready for print",
        color: "dark"
      }
    ]
  end

  defp line_count(work_package) do
    Enum.reduce(work_package.purchase_orders, 0, fn purchase_order, total ->
      total + length(purchase_order.lines)
    end)
  end
end
