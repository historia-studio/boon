defmodule BoonWeb.IntakeLiveTest do
  use BoonWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Boon.Operations

  test "operator can enter a work package with one purchase order and line", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/intake")

    params = %{
      "number" => "10",
      "purchase_orders" => %{
        "0" => %{
          "po_number" => "63129",
          "order_date" => "2026-03-12",
          "revision_date" => "2026-03-12",
          "reference" => "2M017545, ANSI/IEEE GREEN",
          "lines" => %{
            "0" => %{
              "line" => "1",
              "item_number" => "86-SA-T1G50064295",
              "ship_date" => "2026-03-19",
              "quantity" => "2"
            }
          }
        }
      }
    }

    form = form(view, "#intake-form", %{"work_package" => params})

    render_change(form)
    render_submit(form)

    [work_package] = Operations.list_work_packages()

    assert_redirect(view, ~p"/work-packages/#{work_package.id}")

    saved_work_package = Operations.get_work_package!(work_package.id)
    [purchase_order] = saved_work_package.purchase_orders
    [line] = purchase_order.lines

    assert saved_work_package.number == "10"
    assert purchase_order.po_number == "63129"
    assert purchase_order.reference == "2M017545, ANSI/IEEE GREEN"
    assert line.line == 1
    assert line.item_number == "86-SA-T1G50064295"
    assert line.quantity == 2
  end
end
