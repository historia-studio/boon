defmodule BoonWeb.IntakeLive do
  use BoonWeb, :live_view

  alias Boon.Operations

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_scope, nil)
     |> assign(:entry, empty_entry())
     |> assign(:form, to_form(%{}, as: :work_package))
     |> assign(:save_errors, [])
     |> assign(:sample_files, sample_files())}
  end

  @impl true
  def handle_event("change", %{"work_package" => params}, socket) do
    {:noreply,
     socket
     |> assign(:entry, normalize_entry(params))
     |> assign(:save_errors, [])}
  end

  @impl true
  def handle_event("add_purchase_order", _params, socket) do
    entry = update_in(socket.assigns.entry["purchase_orders"], &(&1 ++ [empty_purchase_order()]))

    {:noreply, assign(socket, :entry, entry)}
  end

  @impl true
  def handle_event("remove_purchase_order", %{"index" => index}, socket) do
    purchase_orders = remove_at(socket.assigns.entry["purchase_orders"], index)

    entry =
      if purchase_orders == [] do
        put_in(socket.assigns.entry["purchase_orders"], [empty_purchase_order()])
      else
        put_in(socket.assigns.entry["purchase_orders"], purchase_orders)
      end

    {:noreply, assign(socket, :entry, entry)}
  end

  @impl true
  def handle_event("add_line", %{"po-index" => po_index}, socket) do
    po_index = String.to_integer(po_index)

    entry =
      update_in(socket.assigns.entry["purchase_orders"], fn purchase_orders ->
        List.update_at(purchase_orders, po_index, fn purchase_order ->
          update_in(purchase_order["lines"], &(&1 ++ [empty_line()]))
        end)
      end)

    {:noreply, assign(socket, :entry, entry)}
  end

  @impl true
  def handle_event("remove_line", %{"po-index" => po_index, "line-index" => line_index}, socket) do
    po_index = String.to_integer(po_index)
    line_index = String.to_integer(line_index)

    entry =
      update_in(socket.assigns.entry["purchase_orders"], fn purchase_orders ->
        List.update_at(purchase_orders, po_index, fn purchase_order ->
          lines = remove_at(purchase_order["lines"], line_index)

          if lines == [] do
            put_in(purchase_order["lines"], [empty_line()])
          else
            put_in(purchase_order["lines"], lines)
          end
        end)
      end)

    {:noreply, assign(socket, :entry, entry)}
  end

  @impl true
  def handle_event("save", %{"work_package" => params}, socket) do
    entry = normalize_entry(params)

    with {:ok, attrs} <- validate_entry(entry),
         {:ok, work_package} <- Operations.create_work_package_entry(attrs) do
      {:noreply,
       socket
       |> put_flash(:info, "Work package saved")
       |> push_navigate(to: ~p"/work-packages/#{work_package.id}")}
    else
      {:error, errors} ->
        {:noreply,
         socket
         |> assign(:entry, entry)
         |> assign(:save_errors, List.wrap(errors))}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <section class="grid gap-8 xl:grid-cols-[1.2fr_0.8fr]">
        <BoonWeb.Components.Card.card
          variant="gradient"
          color="danger"
          rounded="extra_large"
          class="app-panel"
          padding="large"
        >
          <BoonWeb.Components.Card.card_content space="large">
            <div class="space-y-4">
              <BoonWeb.Components.Badge.badge
                color="warning"
                variant="bordered"
                rounded="full"
                class="w-fit text-[0.68rem] font-medium uppercase tracking-[0.24em]"
              >
                Intake
              </BoonWeb.Components.Badge.badge>

              <h1 class="text-3xl font-semibold text-stone-50 sm:text-4xl">
                Manual work package data entry
              </h1>

              <p class="max-w-3xl text-sm leading-8 text-red-50/76">
                Start with the operator workflow first: enter the work package number, then add each purchase order and its PO lines exactly as they appear today. ZIP parsing can reuse this same structure afterwards.
              </p>
            </div>

            <BoonWeb.Components.Card.card
              :if={@save_errors != []}
              variant="bordered"
              color="danger"
              rounded="large"
              class="bg-black/15"
              padding="medium"
            >
              <p class="font-semibold text-stone-50">The work package could not be saved.</p>

              <ul class="mt-3 space-y-2 text-sm text-rose-200">
                <li :for={error <- @save_errors}>{error}</li>
              </ul>
            </BoonWeb.Components.Card.card>

            <.form
              for={@form}
              id="intake-form"
              phx-change="change"
              phx-submit="save"
              class="space-y-6"
            >
              <BoonWeb.Components.Card.card
                variant="bordered"
                color="warning"
                rounded="large"
                class="bg-black/15"
                padding="medium"
              >
                <div class="grid gap-4 md:grid-cols-[1fr_auto] md:items-end">
                  <BoonWeb.Components.InputField.input
                    field={@form[:number]}
                    value={@entry["number"]}
                    label="Work package number"
                    placeholder="10"
                    required
                    autocomplete="off"
                  />

                  <div class="app-panel-soft rounded-[1.25rem] px-4 py-3 text-sm text-stone-300">
                    One work package can hold one or more purchase orders.
                  </div>
                </div>
              </BoonWeb.Components.Card.card>

              <div class="space-y-4">
                <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                  <div>
                    <p class="app-kicker text-[0.68rem]">Purchase Orders</p>
                    <p class="mt-2 text-sm text-stone-400">
                      Capture each PDF as one purchase order entry.
                    </p>
                  </div>

                  <BoonWeb.Components.Button.button
                    type="button"
                    phx-click="add_purchase_order"
                    variant="shadow"
                    color="warning"
                    size="small"
                    icon="hero-plus"
                  >
                    Add Purchase Order
                  </BoonWeb.Components.Button.button>
                </div>

                <BoonWeb.Components.Card.card
                  :for={{purchase_order, po_index} <- Enum.with_index(@entry["purchase_orders"])}
                  id={"purchase-order-#{po_index}"}
                  variant="bordered"
                  color="warning"
                  rounded="extra_large"
                  class="app-panel"
                  padding="large"
                >
                  <BoonWeb.Components.Card.card_content space="large">
                    <div class="flex items-center justify-between gap-4">
                      <div>
                        <p class="app-kicker text-[0.68rem]">Purchase Order {po_index + 1}</p>
                        <p class="mt-2 text-sm text-stone-400">Header values from the PDF.</p>
                      </div>

                      <BoonWeb.Components.Button.button
                        :if={length(@entry["purchase_orders"]) > 1}
                        type="button"
                        phx-click="remove_purchase_order"
                        phx-value-index={po_index}
                        variant="transparent"
                        color="danger"
                        size="small"
                      >
                        Remove PO
                      </BoonWeb.Components.Button.button>
                    </div>

                    <div class="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
                      <BoonWeb.Components.InputField.input
                        id={"purchase-orders-#{po_index}-po-number"}
                        name={purchase_order_input_name(@form.name, po_index, "po_number")}
                        value={purchase_order["po_number"]}
                        label="PO number"
                        required
                        autocomplete="off"
                      />
                      <BoonWeb.Components.InputField.input
                        id={"purchase-orders-#{po_index}-order-date"}
                        name={purchase_order_input_name(@form.name, po_index, "order_date")}
                        value={purchase_order["order_date"]}
                        label="Order date"
                        type="date"
                      />
                      <BoonWeb.Components.InputField.input
                        id={"purchase-orders-#{po_index}-revision-date"}
                        name={purchase_order_input_name(@form.name, po_index, "revision_date")}
                        value={purchase_order["revision_date"]}
                        label="Revision date"
                        type="date"
                      />
                      <BoonWeb.Components.InputField.input
                        id={"purchase-orders-#{po_index}-reference"}
                        name={purchase_order_input_name(@form.name, po_index, "reference")}
                        value={purchase_order["reference"]}
                        label="Reference"
                      />
                    </div>

                    <div class="space-y-4 rounded-[1.5rem] border border-white/10 bg-black/20 p-5">
                      <div class="flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
                        <div>
                          <p class="app-kicker text-[0.68rem]">PO Lines</p>
                          <p class="mt-2 text-sm text-stone-400">
                            One row for each line item on the purchase order.
                          </p>
                        </div>

                        <BoonWeb.Components.Button.button
                          type="button"
                          phx-click="add_line"
                          phx-value-po-index={po_index}
                          variant="subtle"
                          color="warning"
                          size="small"
                          icon="hero-plus"
                        >
                          Add Line
                        </BoonWeb.Components.Button.button>
                      </div>

                      <div class="space-y-4">
                        <div
                          :for={{line, line_index} <- Enum.with_index(purchase_order["lines"])}
                          id={"purchase-order-#{po_index}-line-#{line_index}"}
                          class="rounded-[1.5rem] border border-white/10 bg-[#0f0909] p-4"
                        >
                          <div class="mb-4 flex items-center justify-between gap-4">
                            <p class="text-sm font-semibold text-stone-100">Line {line_index + 1}</p>

                            <BoonWeb.Components.Button.button
                              :if={length(purchase_order["lines"]) > 1}
                              type="button"
                              phx-click="remove_line"
                              phx-value-po-index={po_index}
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
                              id={"purchase-orders-#{po_index}-lines-#{line_index}-line"}
                              name={
                                purchase_order_line_input_name(
                                  @form.name,
                                  po_index,
                                  line_index,
                                  "line"
                                )
                              }
                              value={line["line"]}
                              label="Line number"
                              type="number"
                              min="1"
                              required
                            />
                            <BoonWeb.Components.InputField.input
                              id={"purchase-orders-#{po_index}-lines-#{line_index}-item-number"}
                              name={
                                purchase_order_line_input_name(
                                  @form.name,
                                  po_index,
                                  line_index,
                                  "item_number"
                                )
                              }
                              value={line["item_number"]}
                              label="Item number / description"
                              required
                            />
                            <BoonWeb.Components.InputField.input
                              id={"purchase-orders-#{po_index}-lines-#{line_index}-ship-date"}
                              name={
                                purchase_order_line_input_name(
                                  @form.name,
                                  po_index,
                                  line_index,
                                  "ship_date"
                                )
                              }
                              value={line["ship_date"]}
                              label="Ship date"
                              type="date"
                            />
                            <BoonWeb.Components.InputField.input
                              id={"purchase-orders-#{po_index}-lines-#{line_index}-quantity"}
                              name={
                                purchase_order_line_input_name(
                                  @form.name,
                                  po_index,
                                  line_index,
                                  "quantity"
                                )
                              }
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
              </div>

              <BoonWeb.Components.Card.card
                variant="bordered"
                color="danger"
                rounded="large"
                class="bg-black/15"
                padding="medium"
              >
                <div class="flex flex-wrap items-center justify-between gap-3">
                  <p class="text-sm text-stone-400">
                    Save this work package now. Parsing can populate the same fields later.
                  </p>

                  <div class="flex flex-wrap gap-3">
                    <BoonWeb.Components.Button.button_link
                      navigate={~p"/work-packages"}
                      variant="outline"
                      color="warning"
                      size="medium"
                    >
                      View Work Packages
                    </BoonWeb.Components.Button.button_link>
                    <BoonWeb.Components.Button.button
                      type="submit"
                      variant="shadow"
                      color="danger"
                      size="medium"
                      icon="hero-check"
                    >
                      Save Work Package
                    </BoonWeb.Components.Button.button>
                  </div>
                </div>
              </BoonWeb.Components.Card.card>
            </.form>
          </BoonWeb.Components.Card.card_content>
        </BoonWeb.Components.Card.card>

        <BoonWeb.Components.Card.card
          variant="bordered"
          color="warning"
          rounded="extra_large"
          class="app-panel-soft"
          padding="large"
        >
          <BoonWeb.Components.Card.card_content space="large">
            <div class="space-y-3">
              <p class="app-kicker text-[0.68rem]">Operator Notes</p>
              <p class="text-sm leading-7 text-stone-200">
                This first pass is intentionally manual. The point is to prove the workflow shape before the import parser starts inferring values from PDFs.
              </p>
            </div>

            <BoonWeb.Components.Card.card
              variant="bordered"
              color="warning"
              rounded="large"
              class="bg-black/20"
              padding="medium"
            >
              <p class="text-sm uppercase tracking-[0.24em] text-stone-500">Reference Batch</p>

              <p class="mt-3 text-sm text-stone-300">
                wp10 is available in the repo with {length(@sample_files)} purchase order PDFs and covers the variability we should preserve while refining the intake fields.
              </p>

              <div class="mt-4 flex flex-wrap gap-2">
                <BoonWeb.Components.Badge.badge
                  :for={file <- @sample_files}
                  color="warning"
                  variant="outline"
                  rounded="full"
                  class="text-xs"
                >
                  {file}
                </BoonWeb.Components.Badge.badge>
              </div>
            </BoonWeb.Components.Card.card>

            <BoonWeb.Components.Card.card
              variant="bordered"
              color="dark"
              rounded="large"
              class="bg-black/20"
              padding="medium"
            >
              <p class="text-sm text-stone-300">
                Capture the values that already exist in the PDFs now:
              </p>

              <ul class="mt-3 space-y-2 text-sm text-stone-400">
                <li>Work package number</li>
                <li>Purchase order number, dates, and reference</li>
                <li>Line number, item number, ship date, and quantity</li>
              </ul>
            </BoonWeb.Components.Card.card>
          </BoonWeb.Components.Card.card_content>
        </BoonWeb.Components.Card.card>
      </section>
    </Layouts.app>
    """
  end

  defp empty_entry do
    %{"number" => "", "purchase_orders" => [empty_purchase_order()]}
  end

  defp empty_purchase_order do
    %{
      "po_number" => "",
      "order_date" => "",
      "revision_date" => "",
      "reference" => "",
      "lines" => [empty_line()]
    }
  end

  defp empty_line do
    %{"line" => "", "item_number" => "", "ship_date" => "", "quantity" => ""}
  end

  defp normalize_entry(params) do
    %{
      "number" => Map.get(params, "number", ""),
      "purchase_orders" =>
        params
        |> Map.get("purchase_orders", %{})
        |> sort_param_collection()
        |> Enum.map(fn purchase_order ->
          %{
            "po_number" => Map.get(purchase_order, "po_number", ""),
            "order_date" => Map.get(purchase_order, "order_date", ""),
            "revision_date" => Map.get(purchase_order, "revision_date", ""),
            "reference" => Map.get(purchase_order, "reference", ""),
            "lines" =>
              purchase_order
              |> Map.get("lines", %{})
              |> sort_param_collection()
              |> Enum.map(fn line ->
                %{
                  "line" => Map.get(line, "line", ""),
                  "item_number" => Map.get(line, "item_number", ""),
                  "ship_date" => Map.get(line, "ship_date", ""),
                  "quantity" => Map.get(line, "quantity", "")
                }
              end)
              |> ensure_line()
          }
        end)
        |> ensure_purchase_order()
    }
  end

  defp validate_entry(entry) do
    {purchase_orders, errors} =
      entry["purchase_orders"]
      |> Enum.with_index(1)
      |> Enum.reduce({[], []}, fn {purchase_order, purchase_order_index},
                                  {purchase_orders, errors} ->
        {lines, line_errors} = validate_lines(purchase_order["lines"], purchase_order_index)

        {order_date, order_date_error} =
          parse_optional_date(
            purchase_order["order_date"],
            "PO #{purchase_order_index} order date"
          )

        {revision_date, revision_date_error} =
          parse_optional_date(
            purchase_order["revision_date"],
            "PO #{purchase_order_index} revision date"
          )

        purchase_order_errors =
          errors ++
            line_errors ++
            List.wrap(order_date_error) ++
            List.wrap(revision_date_error) ++
            required_field_error(purchase_order["po_number"], "PO #{purchase_order_index} number")

        normalized_purchase_order = %{
          po_number: normalize_text(purchase_order["po_number"]),
          order_date: order_date,
          revision_date: revision_date,
          reference: normalize_optional_text(purchase_order["reference"]),
          lines: lines
        }

        {[normalized_purchase_order | purchase_orders], purchase_order_errors}
      end)

    errors = required_field_error(entry["number"], "Work package number") ++ errors

    if errors == [] do
      {:ok,
       %{
         number: normalize_text(entry["number"]),
         purchase_orders: Enum.reverse(purchase_orders)
       }}
    else
      {:error, errors}
    end
  end

  defp validate_lines(lines, purchase_order_index) do
    lines
    |> Enum.with_index(1)
    |> Enum.reduce({[], []}, fn {line, line_index}, {normalized_lines, errors} ->
      {line_number, line_number_error} =
        parse_positive_integer(
          line["line"],
          "PO #{purchase_order_index} line #{line_index} line number"
        )

      {quantity, quantity_error} =
        parse_positive_integer(
          line["quantity"],
          "PO #{purchase_order_index} line #{line_index} quantity"
        )

      {ship_date, ship_date_error} =
        parse_optional_date(
          line["ship_date"],
          "PO #{purchase_order_index} line #{line_index} ship date"
        )

      line_errors =
        errors ++
          required_field_error(
            line["item_number"],
            "PO #{purchase_order_index} line #{line_index} item number"
          ) ++
          List.wrap(line_number_error) ++
          List.wrap(quantity_error) ++
          List.wrap(ship_date_error)

      normalized_line = %{
        line: line_number,
        item_number: normalize_text(line["item_number"]),
        ship_date: ship_date,
        quantity: quantity
      }

      {[normalized_line | normalized_lines], line_errors}
    end)
    |> then(fn {normalized_lines, errors} -> {Enum.reverse(normalized_lines), errors} end)
  end

  defp parse_positive_integer(value, label) do
    case normalize_text(value) do
      "" ->
        {nil, "#{label} is required"}

      normalized ->
        case Integer.parse(normalized) do
          {integer, ""} when integer > 0 -> {integer, nil}
          _ -> {nil, "#{label} must be a positive whole number"}
        end
    end
  end

  defp parse_optional_date(value, label) do
    case normalize_text(value) do
      "" ->
        {nil, nil}

      normalized ->
        case Date.from_iso8601(normalized) do
          {:ok, date} -> {date, nil}
          {:error, _reason} -> {nil, "#{label} must be a valid date"}
        end
    end
  end

  defp required_field_error(value, label) do
    if normalize_text(value) == "", do: ["#{label} is required"], else: []
  end

  defp normalize_text(value), do: value |> to_string() |> String.trim()

  defp normalize_optional_text(value) do
    case normalize_text(value) do
      "" -> nil
      normalized -> normalized
    end
  end

  defp sort_param_collection(values) when is_list(values), do: values

  defp sort_param_collection(values) when is_map(values) do
    values
    |> Enum.sort_by(fn {index, _value} -> String.to_integer(index) end)
    |> Enum.map(fn {_index, value} -> value end)
  end

  defp sort_param_collection(_values), do: []

  defp ensure_purchase_order([]), do: [empty_purchase_order()]
  defp ensure_purchase_order(purchase_orders), do: purchase_orders

  defp ensure_line([]), do: [empty_line()]
  defp ensure_line(lines), do: lines

  defp remove_at(list, index) when is_binary(index), do: remove_at(list, String.to_integer(index))
  defp remove_at(list, index), do: List.delete_at(list, index)

  defp purchase_order_input_name(form_name, po_index, field_name) do
    "#{form_name}[purchase_orders][#{po_index}][#{field_name}]"
  end

  defp purchase_order_line_input_name(form_name, po_index, line_index, field_name) do
    "#{form_name}[purchase_orders][#{po_index}][lines][#{line_index}][#{field_name}]"
  end

  defp sample_files do
    "c:/Users/jesse/dev/boon/reference/wp10"
    |> File.ls!()
    |> Enum.sort()
  end
end
