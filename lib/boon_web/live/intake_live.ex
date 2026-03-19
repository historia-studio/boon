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
        <div class="space-y-6 rounded-[2rem] border border-white/10 bg-white/5 p-8 shadow-2xl shadow-black/20">
          <div class="space-y-3">
            <p class="text-sm uppercase tracking-[0.3em] text-amber-300">Intake</p>

            <h1 class="text-3xl font-semibold text-white">Manual work package data entry</h1>

            <p class="max-w-3xl text-sm leading-7 text-stone-300">
              Start with the operator workflow first: enter the work package number, then add each purchase order and its PO lines exactly as they appear today. ZIP parsing can reuse this same structure afterwards.
            </p>
          </div>

          <div
            :if={@save_errors != []}
            class="rounded-3xl border border-rose-400/20 bg-rose-400/10 p-5 text-sm text-rose-100"
          >
            <p class="font-semibold text-white">The work package could not be saved.</p>

            <ul class="mt-3 space-y-2">
              <li :for={error <- @save_errors}>{error}</li>
            </ul>
          </div>

          <.form for={@form} id="intake-form" phx-change="change" phx-submit="save" class="space-y-6">
            <div class="rounded-3xl border border-white/10 bg-stone-900/70 p-6">
              <div class="grid gap-4 md:grid-cols-[1fr_auto] md:items-end">
                <.input
                  field={@form[:number]}
                  value={@entry["number"]}
                  label="Work package number"
                  placeholder="10"
                  required
                  autocomplete="off"
                />
                <div class="rounded-2xl border border-white/10 bg-black/20 px-4 py-3 text-sm text-stone-300">
                  One work package can hold one or more purchase orders.
                </div>
              </div>
            </div>

            <div class="space-y-4">
              <div class="flex items-center justify-between">
                <div>
                  <p class="text-sm uppercase tracking-[0.25em] text-stone-500">Purchase Orders</p>

                  <p class="mt-1 text-sm text-stone-400">
                    Capture each PDF as one purchase order entry.
                  </p>
                </div>
                 <.button type="button" phx-click="add_purchase_order">Add Purchase Order</.button>
              </div>

              <section
                :for={{purchase_order, po_index} <- Enum.with_index(@entry["purchase_orders"])}
                id={"purchase-order-#{po_index}"}
                class="space-y-5 rounded-[2rem] border border-white/10 bg-stone-900/70 p-6"
              >
                <div class="flex items-center justify-between gap-4">
                  <div>
                    <p class="text-sm uppercase tracking-[0.25em] text-amber-300">
                      Purchase Order {po_index + 1}
                    </p>

                    <p class="mt-1 text-sm text-stone-400">Header values from the PDF.</p>
                  </div>

                  <button
                    :if={length(@entry["purchase_orders"]) > 1}
                    type="button"
                    phx-click="remove_purchase_order"
                    phx-value-index={po_index}
                    class="rounded-full border border-white/10 px-4 py-2 text-sm text-stone-300 transition hover:border-rose-300/40 hover:text-white"
                  >
                    Remove PO
                  </button>
                </div>

                <div class="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
                  <.input
                    id={"purchase-orders-#{po_index}-po-number"}
                    name={purchase_order_input_name(@form.name, po_index, "po_number")}
                    value={purchase_order["po_number"]}
                    label="PO number"
                    required
                    autocomplete="off"
                  />
                  <.input
                    id={"purchase-orders-#{po_index}-order-date"}
                    name={purchase_order_input_name(@form.name, po_index, "order_date")}
                    value={purchase_order["order_date"]}
                    label="Order date"
                    type="date"
                  />
                  <.input
                    id={"purchase-orders-#{po_index}-revision-date"}
                    name={purchase_order_input_name(@form.name, po_index, "revision_date")}
                    value={purchase_order["revision_date"]}
                    label="Revision date"
                    type="date"
                  />
                  <.input
                    id={"purchase-orders-#{po_index}-reference"}
                    name={purchase_order_input_name(@form.name, po_index, "reference")}
                    value={purchase_order["reference"]}
                    label="Reference"
                  />
                </div>

                <div class="space-y-4 rounded-3xl border border-white/10 bg-black/20 p-5">
                  <div class="flex items-center justify-between gap-4">
                    <div>
                      <p class="text-sm uppercase tracking-[0.25em] text-stone-500">PO Lines</p>

                      <p class="mt-1 text-sm text-stone-400">
                        One row for each line item on the purchase order.
                      </p>
                    </div>

                    <.button type="button" phx-click="add_line" phx-value-po-index={po_index}>
                      Add Line
                    </.button>
                  </div>

                  <div class="space-y-4">
                    <div
                      :for={{line, line_index} <- Enum.with_index(purchase_order["lines"])}
                      id={"purchase-order-#{po_index}-line-#{line_index}"}
                      class="rounded-3xl border border-white/10 bg-stone-950/70 p-4"
                    >
                      <div class="mb-4 flex items-center justify-between gap-4">
                        <p class="text-sm font-semibold text-white">Line {line_index + 1}</p>

                        <button
                          :if={length(purchase_order["lines"]) > 1}
                          type="button"
                          phx-click="remove_line"
                          phx-value-po-index={po_index}
                          phx-value-line-index={line_index}
                          class="rounded-full border border-white/10 px-3 py-1.5 text-xs uppercase tracking-[0.2em] text-stone-300 transition hover:border-rose-300/40 hover:text-white"
                        >
                          Remove
                        </button>
                      </div>

                      <div class="grid gap-4 md:grid-cols-2 xl:grid-cols-4">
                        <.input
                          id={"purchase-orders-#{po_index}-lines-#{line_index}-line"}
                          name={
                            purchase_order_line_input_name(@form.name, po_index, line_index, "line")
                          }
                          value={line["line"]}
                          label="Line number"
                          type="number"
                          min="1"
                          required
                        />
                        <.input
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
                        <.input
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
                        <.input
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
              </section>
            </div>

            <div class="flex flex-wrap items-center justify-between gap-3 rounded-3xl border border-white/10 bg-stone-900/70 p-6">
              <p class="text-sm text-stone-400">
                Save this work package now. Parsing can populate the same fields later.
              </p>

              <div class="flex flex-wrap gap-3">
                <.button navigate={~p"/work-packages"}>View Work Packages</.button>
                <.button type="submit" variant="primary">Save Work Package</.button>
              </div>
            </div>
          </.form>
        </div>

        <aside class="space-y-6 rounded-[2rem] border border-amber-400/20 bg-amber-300/10 p-8">
          <div class="space-y-3">
            <p class="text-sm uppercase tracking-[0.3em] text-amber-200">Operator Notes</p>

            <p class="text-sm leading-7 text-stone-200">
              This first pass is intentionally manual. The point is to prove the workflow shape before the import parser starts inferring values from PDFs.
            </p>
          </div>

          <div class="rounded-3xl border border-white/10 bg-black/20 p-6">
            <p class="text-sm uppercase tracking-[0.25em] text-stone-500">Reference Batch</p>

            <p class="mt-2 text-sm text-stone-300">
              `wp10` is available in the repo with {length(@sample_files)} purchase order PDFs and covers the variability we should preserve while refining the intake fields.
            </p>

            <div class="mt-4 flex flex-wrap gap-2">
              <span
                :for={file <- @sample_files}
                class="rounded-full border border-white/10 bg-stone-950/70 px-3 py-1 text-xs text-stone-300"
              >
                {file}
              </span>
            </div>
          </div>

          <div class="rounded-3xl border border-white/10 bg-black/20 p-6 text-sm text-stone-300">
            Capture the values that already exist in the PDFs now:
            <ul class="mt-3 space-y-2 text-stone-400">
              <li>Work package number</li>

              <li>Purchase order number, dates, and reference</li>

              <li>Line number, item number, ship date, and quantity</li>
            </ul>
          </div>
        </aside>
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
