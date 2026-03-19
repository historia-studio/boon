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
      <section class="space-y-6">
        <BoonWeb.Components.Card.card
          variant="gradient"
          color="danger"
          rounded="extra_large"
          class="app-panel"
          padding="large"
        >
          <BoonWeb.Components.Card.card_content space="large">
            <div class="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
              <div class="space-y-3">
                <BoonWeb.Components.Badge.badge
                  color="warning"
                  variant="bordered"
                  rounded="full"
                  class="w-fit text-[0.68rem] font-medium uppercase tracking-[0.24em]"
                >
                  Work Package
                </BoonWeb.Components.Badge.badge>

                <h1 class="text-4xl font-semibold text-stone-50">WP {@work_package.number}</h1>

                <p class="max-w-2xl text-sm leading-7 text-red-50/76">
                  This is the current intake shape: one work package with its purchase orders and PO lines ready for review, print, and later PDF-based import.
                </p>
              </div>

              <div class="flex flex-wrap gap-3">
                <BoonWeb.Components.Button.button_link
                  navigate={~p"/intake"}
                  variant="shadow"
                  color="danger"
                  icon="hero-plus"
                  size="medium"
                >
                  Enter Another
                </BoonWeb.Components.Button.button_link>
                <BoonWeb.Components.Button.button_link
                  navigate={~p"/work-packages"}
                  variant="outline"
                  color="warning"
                  size="medium"
                >
                  All Work Packages
                </BoonWeb.Components.Button.button_link>
              </div>
            </div>

            <div class="grid gap-4 md:grid-cols-3">
              <BoonWeb.Components.Card.card
                variant="bordered"
                color="danger"
                rounded="large"
                class="bg-black/20"
                padding="medium"
              >
                <p class="text-sm text-stone-400">Purchase Orders</p>
                <p class="mt-3 text-3xl font-semibold text-stone-50">
                  {length(@work_package.purchase_orders)}
                </p>
              </BoonWeb.Components.Card.card>

              <BoonWeb.Components.Card.card
                variant="bordered"
                color="warning"
                rounded="large"
                class="bg-black/20"
                padding="medium"
              >
                <p class="text-sm text-stone-400">PO Lines</p>
                <p class="mt-3 text-3xl font-semibold text-stone-50">{line_count(@work_package)}</p>
              </BoonWeb.Components.Card.card>

              <BoonWeb.Components.Card.card
                variant="bordered"
                color="dark"
                rounded="large"
                class="bg-black/20"
                padding="medium"
              >
                <p class="text-sm text-stone-400">Status</p>
                <p class="mt-3 text-lg font-semibold text-stone-50">Manual entry complete</p>
              </BoonWeb.Components.Card.card>
            </div>
          </BoonWeb.Components.Card.card_content>
        </BoonWeb.Components.Card.card>

        <div class="space-y-4">
          <BoonWeb.Components.Card.card
            :for={purchase_order <- @work_package.purchase_orders}
            id={"purchase-order-#{purchase_order.id}"}
            variant="bordered"
            color="warning"
            rounded="extra_large"
            class="app-panel"
            padding="large"
          >
            <BoonWeb.Components.Card.card_content space="large">
              <div class="grid gap-4 lg:grid-cols-[1.1fr_0.9fr] lg:items-start">
                <div>
                  <p class="app-kicker text-[0.68rem]">Purchase Order</p>
                  <h2 class="mt-3 text-2xl font-semibold text-stone-50">
                    {purchase_order.po_number}
                  </h2>

                  <p :if={purchase_order.reference} class="mt-2 text-sm text-stone-400">
                    {purchase_order.reference}
                  </p>
                </div>

                <dl class="grid gap-3 sm:grid-cols-3">
                  <div class="app-panel-soft rounded-[1.25rem] px-4 py-4">
                    <dt class="text-xs uppercase tracking-[0.24em] text-stone-500">Order Date</dt>
                    <dd class="mt-2 text-sm text-stone-100">
                      {format_date(purchase_order.order_date)}
                    </dd>
                  </div>

                  <div class="app-panel-soft rounded-[1.25rem] px-4 py-4">
                    <dt class="text-xs uppercase tracking-[0.24em] text-stone-500">Revision Date</dt>
                    <dd class="mt-2 text-sm text-stone-100">
                      {format_date(purchase_order.revision_date)}
                    </dd>
                  </div>

                  <div class="app-panel-soft rounded-[1.25rem] px-4 py-4">
                    <dt class="text-xs uppercase tracking-[0.24em] text-stone-500">PO Lines</dt>
                    <dd class="mt-2 text-sm text-stone-100">{length(purchase_order.lines)}</dd>
                  </div>
                </dl>
              </div>

              <BoonWeb.Components.Table.table
                id={"purchase-order-lines-#{purchase_order.id}"}
                rows={purchase_order.lines}
                row_id={fn line -> "purchase-order-line-#{line.id}" end}
                variant="base"
                rounded="large"
                class="text-stone-200"
              >
                <:col :let={line} label="Line">
                  <span class="font-semibold text-stone-50">{line.line}</span>
                </:col>
                <:col :let={line} label="Item Number / Description">
                  {line.item_number}
                </:col>
                <:col :let={line} label="Ship Date">
                  <span class="text-stone-400">{format_date(line.ship_date)}</span>
                </:col>
                <:col :let={line} label="Quantity">
                  {line.quantity}
                </:col>
              </BoonWeb.Components.Table.table>
            </BoonWeb.Components.Card.card_content>
          </BoonWeb.Components.Card.card>
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
