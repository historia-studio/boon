defmodule BoonWeb.Components.PurchaseOrderEditor do
  use BoonWeb, :html

  alias Boon.ShippingLocation

  attr :form_name, :string, required: true
  attr :po_index, :integer, required: true
  attr :po_number, :string, default: ""
  attr :order_date, :string, default: ""
  attr :revision_date, :string, default: ""
  attr :reference, :string, default: ""
  attr :ship_to, :string, default: ""
  attr :lines, :list, default: []
  attr :collapsed, :boolean, default: false
  attr :purchase_order_count, :integer, default: 1
  attr :show_toggle, :boolean, default: true
  attr :show_remove_purchase_order, :boolean, default: true
  attr :add_line_event, :string, default: "add_line"
  attr :remove_line_event, :string, default: "remove_line"
  attr :remove_purchase_order_event, :string, default: "remove_purchase_order"
  attr :toggle_event, :string, default: "toggle_purchase_order"
  attr :class, :string, default: nil

  def editor(assigns) do
    assigns =
      assigns
      |> assign(:card_class, Enum.join(Enum.reject(["app-panel", assigns.class], &is_nil/1), " "))
      |> assign(:editor_lines, assigns.lines)

    ~H"""
    <BoonWeb.Components.Card.card
      id={"purchase-order-#{@po_index}"}
      variant="bordered"
      color="warning"
      rounded="extra_large"
      class={@card_class}
      padding="large"
    >
      <BoonWeb.Components.Card.card_content space="large">
        <div class="flex flex-wrap items-center justify-between gap-4">
          <%= if @show_toggle do %>
            <button
              id={"purchase-order-#{@po_index}-toggle"}
              type="button"
              phx-click={@toggle_event}
              phx-value-index={@po_index}
              class="flex items-center gap-3 text-left"
            >
              <.icon
                name={if @collapsed, do: "hero-chevron-right", else: "hero-chevron-down"}
                class="h-4 w-4 text-amber-300"
              />
              <span class="app-kicker text-[0.68rem]">
                {purchase_order_title(@po_number, @po_index)}
              </span>
            </button>
          <% else %>
            <div class="flex items-center gap-3 text-left">
              <span class="app-kicker text-[0.68rem]">
                {purchase_order_title(@po_number, @po_index)}
              </span>
            </div>
          <% end %>

          <div class="flex flex-wrap gap-3">
            <BoonWeb.Components.Button.button
              id={"purchase-order-#{@po_index}-add-line"}
              type="button"
              phx-click={@add_line_event}
              phx-value-po-index={@po_index}
              variant="subtle"
              color="warning"
              size="small"
              icon="hero-plus"
            >
              Add Line
            </BoonWeb.Components.Button.button>
            <BoonWeb.Components.Button.button
              :if={@show_remove_purchase_order and @purchase_order_count > 1}
              id={"purchase-order-#{@po_index}-remove"}
              type="button"
              phx-click={@remove_purchase_order_event}
              phx-value-index={@po_index}
              variant="transparent"
              color="danger"
              size="small"
            >
              Remove PO
            </BoonWeb.Components.Button.button>
          </div>
        </div>

        <div :if={!@collapsed} class="space-y-4">
          <div class="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
            <BoonWeb.Components.InputField.input
              id={"purchase-orders-#{@po_index}-po-number"}
              name={purchase_order_input_name(@form_name, @po_index, "po_number")}
              value={@po_number}
              label="PO number"
              required
              autocomplete="off"
            />
            <BoonWeb.Components.InputField.input
              id={"purchase-orders-#{@po_index}-order-date"}
              name={purchase_order_input_name(@form_name, @po_index, "order_date")}
              value={@order_date}
              label="Order date"
              type="date"
            />
            <BoonWeb.Components.InputField.input
              id={"purchase-orders-#{@po_index}-revision-date"}
              name={purchase_order_input_name(@form_name, @po_index, "revision_date")}
              value={@revision_date}
              label="Revision date"
              type="date"
            />
            <BoonWeb.Components.InputField.input
              id={"purchase-orders-#{@po_index}-reference"}
              name={purchase_order_input_name(@form_name, @po_index, "reference")}
              value={@reference}
              label="Reference"
            />
            <BoonWeb.Components.InputField.input
              id={"purchase-orders-#{@po_index}-ship-to"}
              name={purchase_order_input_name(@form_name, @po_index, "ship_to")}
              value={@ship_to}
              label="Ship To"
              type="select"
              options={ShippingLocation.select_options()}
              prompt="Select shipping location"
              required
            />
          </div>

          <div class="space-y-4">
            <div
              :for={{line, line_index} <- Enum.with_index(@editor_lines)}
              id={"purchase-order-#{@po_index}-line-#{line_index}"}
              class="rounded-[1.5rem] border border-white/10 bg-[#0f0909] p-4"
            >
              <div class="mb-4 flex items-center justify-end gap-4">
                <BoonWeb.Components.Button.button
                  :if={length(@editor_lines) > 1}
                  id={"purchase-order-#{@po_index}-line-#{line_index}-remove"}
                  type="button"
                  phx-click={@remove_line_event}
                  phx-value-po-index={@po_index}
                  phx-value-line-index={line_index}
                  variant="transparent"
                  color="danger"
                  size="extra_small"
                >
                  Remove
                </BoonWeb.Components.Button.button>
              </div>

              <div class="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
                <BoonWeb.Components.InputField.input
                  id={"purchase-orders-#{@po_index}-lines-#{line_index}-line"}
                  name={purchase_order_line_input_name(@form_name, @po_index, line_index, "line")}
                  value={line["line"]}
                  label="Line number"
                  type="number"
                  min="1"
                  required
                />
                <BoonWeb.Components.InputField.input
                  id={"purchase-orders-#{@po_index}-lines-#{line_index}-item-number"}
                  name={
                    purchase_order_line_input_name(@form_name, @po_index, line_index, "item_number")
                  }
                  value={line["item_number"]}
                  label="Item number / description"
                  required
                />
                <BoonWeb.Components.InputField.input
                  id={"purchase-orders-#{@po_index}-lines-#{line_index}-ship-date"}
                  name={
                    purchase_order_line_input_name(@form_name, @po_index, line_index, "ship_date")
                  }
                  value={line["ship_date"]}
                  label="Ship date"
                  type="date"
                />
                <BoonWeb.Components.InputField.input
                  id={"purchase-orders-#{@po_index}-lines-#{line_index}-quantity"}
                  name={purchase_order_line_input_name(@form_name, @po_index, line_index, "quantity")}
                  value={line["quantity"]}
                  label="Quantity"
                  type="number"
                  min="1"
                  step="1"
                  required
                />
              </div>
            </div>
          </div>
        </div>
      </BoonWeb.Components.Card.card_content>
    </BoonWeb.Components.Card.card>
    """
  end

  def purchase_order_title(po_number, po_index) do
    case po_number |> to_string() |> String.trim() do
      "" -> "PO Draft #{po_index + 1}"
      value -> "PO #{value}"
    end
  end

  def purchase_order_input_name(form_name, po_index, field_name) do
    "#{form_name}[purchase_orders][#{po_index}][#{field_name}]"
  end

  def purchase_order_line_input_name(form_name, po_index, line_index, field_name) do
    "#{form_name}[purchase_orders][#{po_index}][lines][#{line_index}][#{field_name}]"
  end
end
