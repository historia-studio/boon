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
      <BoonWeb.Components.Card.card
        variant="bordered"
        color="danger"
        rounded="extra_large"
        class="app-panel"
        padding="large"
      >
        <BoonWeb.Components.Card.card_content space="large">
          <div class="flex flex-col gap-4 sm:flex-row sm:items-end sm:justify-between">
            <div class="space-y-3">
              <BoonWeb.Components.Badge.badge
                color="warning"
                variant="bordered"
                rounded="full"
                class="w-fit text-[0.68rem] font-medium uppercase tracking-[0.24em]"
              >
                Work Packages
              </BoonWeb.Components.Badge.badge>

              <h1 class="text-3xl font-semibold text-stone-50">Captured intake records</h1>

              <p class="max-w-2xl text-sm leading-7 app-copy-muted">
                Manual intake writes directly into the work package hierarchy. Review and printing can build on the exact same records once those steps are implemented.
              </p>
            </div>

            <BoonWeb.Components.Button.button_link
              navigate={~p"/intake"}
              variant="shadow"
              color="danger"
              icon="hero-plus"
              size="medium"
            >
              Enter Work Package
            </BoonWeb.Components.Button.button_link>
          </div>

          <div
            :if={@work_packages == []}
            class="rounded-[1.5rem] border border-dashed border-white/10 px-6 py-8 text-sm text-stone-400"
          >
            No work packages have been entered yet.
          </div>

          <BoonWeb.Components.Table.table
            :if={@work_packages != []}
            id="work-packages-table"
            rows={@work_packages}
            row_id={fn work_package -> "work-package-#{work_package.id}" end}
            variant="base_hoverable"
            rounded="large"
            class="text-stone-200"
          >
            <:col :let={work_package} label="Work Package">
              <span class="font-semibold text-stone-50">WP {work_package.number}</span>
            </:col>
            <:col :let={work_package} label="Purchase Orders">
              {length(work_package.purchase_orders)}
            </:col>
            <:col :let={work_package} label="PO Lines">
              {line_count(work_package)}
            </:col>
            <:col :let={work_package} label="Entered">
              <span class="text-stone-400">{format_datetime(work_package.inserted_at)}</span>
            </:col>
            <:action :let={work_package}>
              <BoonWeb.Components.Button.button_link
                navigate={~p"/work-packages/#{work_package.id}"}
                variant="subtle"
                color="warning"
                size="extra_small"
              >
                Open
              </BoonWeb.Components.Button.button_link>
            </:action>
          </BoonWeb.Components.Table.table>
        </BoonWeb.Components.Card.card_content>
      </BoonWeb.Components.Card.card>
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
