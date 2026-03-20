defmodule BoonWeb.IntakeLiveTest do
  use BoonWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Boon.Operations

  setup do
    original_parser = Application.get_env(:boon, :pdf_intake_parser)

    on_exit(fn ->
      Application.put_env(:boon, :pdf_intake_parser, original_parser)
    end)

    :ok
  end

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
          "ship_to" => "chilliwack",
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
    assert purchase_order.ship_to == "chilliwack"
    assert line.line == 1
    assert line.item_number == "86-SA-T1G50064295"
    assert line.quantity == 2
  end

  test "operator can import a pdf into the intake form before saving", %{conn: conn} do
    Application.put_env(:boon, :pdf_intake_parser, Boon.PDF.ParserStub)

    {:ok, view, _html} = live(conn, ~p"/intake")

    pdf_path = Path.expand("../../../reference/wp10/63129.pdf", __DIR__)

    upload =
      file_input(view, "#import-form", :purchase_order_pdf, [
        %{
          last_modified: 1_710_000_000_000,
          name: "63129.pdf",
          content: File.read!(pdf_path),
          type: "application/pdf"
        }
      ])

    render_upload(upload, "63129.pdf")

    assert render(view) =~ "63129.pdf"

    view
    |> form("#import-form")
    |> render_submit()

    assert has_element?(view, "#purchase-orders-0-po-number[value='63129']")
    assert has_element?(view, "#purchase-orders-0-order-date[value='2026-03-12']")
    assert has_element?(view, "#purchase-orders-0-ship-to option[selected][value='chilliwack']")
    assert has_element?(view, "#purchase-orders-0-lines-0-item-number[value='86-SA-T1G50064295']")
  end

  test "operator can save duplicate line numbers within a purchase order", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/intake")

    params = %{
      "number" => "11",
      "purchase_orders" => %{
        "0" => %{
          "po_number" => "63130",
          "order_date" => "2026-03-12",
          "revision_date" => "2026-03-12",
          "reference" => "2M017549, 1730, RAD, SEA FOAM",
          "ship_to" => "chilliwack",
          "lines" => %{
            "0" => %{
              "line" => "2",
              "item_number" => "86-SA-T1C2042000",
              "ship_date" => "2026-03-26",
              "quantity" => "3"
            },
            "1" => %{
              "line" => "2",
              "item_number" => "86-SA-L1A2027900",
              "ship_date" => "2026-03-26",
              "quantity" => "2"
            }
          }
        }
      }
    }

    render_submit(view, "save", %{"work_package" => params})

    [work_package] = Enum.filter(Operations.list_work_packages(), &(&1.number == "11"))

    assert_redirect(view, ~p"/work-packages/#{work_package.id}")

    saved_work_package = Operations.get_work_package!(work_package.id)
    [purchase_order] = saved_work_package.purchase_orders

    assert Enum.map(purchase_order.lines, & &1.line) == [2, 2]
    assert Enum.map(purchase_order.lines, & &1.item_number) == [
             "86-SA-T1C2042000",
             "86-SA-L1A2027900"
           ]
  end
end
