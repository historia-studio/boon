defmodule BoonWeb.WorkPackageShowLiveTest do
  use BoonWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Boon.Operations

  defmodule LabelTransportStub do
    @behaviour Boon.Printing.LabelTransport

    @impl true
    def print(printer_name, zpl, opts) do
      if notify = Keyword.get(opts, :notify) do
        send(notify, {:label_printed, printer_name, zpl})
      end

      Keyword.get(opts, :result, :ok)
    end
  end

  setup do
    printing_config = Application.get_env(:boon, :printing, [])

    Application.put_env(
      :boon,
      :printing,
      Keyword.merge(printing_config,
        label_transport_module: LabelTransportStub,
        label_transport_opts: [notify: self()]
      )
    )

    on_exit(fn ->
      Application.put_env(:boon, :printing, printing_config)
    end)

    :ok
  end

  test "work package screen prints labels for work package, purchase order, and line", %{
    conn: conn
  } do
    work_package = work_package_fixture()
    [purchase_order] = work_package.purchase_orders
    [tank_line, cabinet_line, lid_line] = purchase_order.lines

    {:ok, view, _html} = live(conn, ~p"/work-packages/#{work_package.id}")

    assert has_element?(view, "#print-work-package-labels")
    assert has_element?(view, "#print-purchase-order-labels-#{purchase_order.id}")
    assert has_element?(view, "#print-line-labels-#{tank_line.id}")
    assert has_element?(view, "#print-line-labels-#{lid_line.id}")
    assert has_element?(view, "#print-line-labels-#{cabinet_line.id}[disabled]")

    view
    |> element("#print-work-package-labels")
    |> render_click()

    assert_receive {:label_printed, "Label Maker", work_package_zpl}
    assert work_package_zpl =~ tank_line.item_number
    assert work_package_zpl =~ lid_line.item_number
    assert render(view) =~ "Printed 2 labels to Label Maker."

    view
    |> element("#print-purchase-order-labels-#{purchase_order.id}")
    |> render_click()

    assert_receive {:label_printed, "Label Maker", purchase_order_zpl}
    assert purchase_order_zpl =~ tank_line.item_number
    assert purchase_order_zpl =~ lid_line.item_number

    view
    |> element("#print-line-labels-#{tank_line.id}")
    |> render_click()

    assert_receive {:label_printed, "Label Maker", line_zpl}
    assert line_zpl =~ tank_line.item_number
  end

  defp work_package_fixture do
    {:ok, work_package} =
      Operations.create_work_package_entry(%{
        number: "WP-#{System.unique_integer([:positive])}",
        purchase_orders: [
          %{
            po_number: "PO-#{System.unique_integer([:positive])}",
            order_date: ~D[2026-03-20],
            revision_date: ~D[2026-03-21],
            reference: "TRANSFORMER, ANSI/IEEE GREEN, PRIORITY",
            ship_to: "chilliwack",
            lines: [
              %{line: 1, item_number: "86-SA-T100", quantity: 1, ship_date: ~D[2026-04-10]},
              %{line: 2, item_number: "86-SA-C100", quantity: 1, ship_date: ~D[2026-04-10]},
              %{line: 3, item_number: "86-SA-L100", quantity: 1, ship_date: ~D[2026-04-10]}
            ]
          }
        ]
      })

    Operations.get_work_package!(work_package.id)
  end
end
