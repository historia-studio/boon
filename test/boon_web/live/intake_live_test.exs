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

  test "duplicate work package updates a matching purchase order", %{conn: conn} do
    {:ok, existing_work_package} =
      Operations.create_work_package_entry(%{
        number: "12",
        purchase_orders: [
          %{
            po_number: "63131",
            order_date: ~D[2026-03-12],
            revision_date: ~D[2026-03-12],
            reference: "OLD REFERENCE",
            ship_to: "chilliwack",
            lines: [
              %{line: 1, item_number: "86-SA-T100", ship_date: ~D[2026-03-20], quantity: 1}
            ]
          }
        ]
      })

    {:ok, view, _html} = live(conn, ~p"/intake")

    params = %{
      "number" => "12",
      "purchase_orders" => %{
        "0" => %{
          "po_number" => "63131",
          "order_date" => "2026-03-14",
          "revision_date" => "2026-03-12",
          "reference" => "UPDATED REFERENCE",
          "ship_to" => "spruce_grove",
          "lines" => %{
            "0" => %{
              "line" => "2",
              "item_number" => "86-SA-T200",
              "ship_date" => "2026-03-26",
              "quantity" => "3"
            }
          }
        }
      }
    }

    render_submit(view, "save", %{"work_package" => params})

    assert_redirect(view, ~p"/work-packages/#{existing_work_package.id}")

    saved_work_package = Operations.get_work_package!(existing_work_package.id)
    assert saved_work_package.number == "12"
    assert length(saved_work_package.purchase_orders) == 1

    [purchase_order] = saved_work_package.purchase_orders
    assert purchase_order.po_number == "63131"
    assert purchase_order.order_date == ~D[2026-03-14]
    assert purchase_order.reference == "UPDATED REFERENCE"
    assert purchase_order.ship_to == "spruce_grove"
    assert Enum.map(purchase_order.lines, & &1.line) == [2]
    assert Enum.map(purchase_order.lines, & &1.item_number) == ["86-SA-T200"]
  end

  test "duplicate work package creates a new purchase order when no match exists", %{conn: conn} do
    {:ok, existing_work_package} =
      Operations.create_work_package_entry(%{
        number: "13",
        purchase_orders: [
          %{
            po_number: "63132",
            order_date: ~D[2026-03-12],
            revision_date: ~D[2026-03-12],
            reference: "EXISTING PO",
            ship_to: "chilliwack",
            lines: [
              %{line: 1, item_number: "86-SA-T300", ship_date: ~D[2026-03-20], quantity: 1}
            ]
          }
        ]
      })

    {:ok, view, _html} = live(conn, ~p"/intake")

    params = %{
      "number" => "13",
      "purchase_orders" => %{
        "0" => %{
          "po_number" => "63133",
          "order_date" => "2026-03-15",
          "revision_date" => "2026-03-15",
          "reference" => "NEW PO",
          "ship_to" => "spruce_grove",
          "lines" => %{
            "0" => %{
              "line" => "1",
              "item_number" => "86-SA-L300",
              "ship_date" => "2026-03-27",
              "quantity" => "2"
            }
          }
        }
      }
    }

    render_submit(view, "save", %{"work_package" => params})

    assert_redirect(view, ~p"/work-packages/#{existing_work_package.id}")

    saved_work_package = Operations.get_work_package!(existing_work_package.id)
    assert length(saved_work_package.purchase_orders) == 2

    assert Enum.map(saved_work_package.purchase_orders, & &1.po_number) == ["63132", "63133"]

    new_purchase_order = Enum.find(saved_work_package.purchase_orders, &(&1.po_number == "63133"))
    assert new_purchase_order.reference == "NEW PO"
    assert new_purchase_order.ship_to == "spruce_grove"
    assert Enum.map(new_purchase_order.lines, & &1.item_number) == ["86-SA-L300"]
  end
end
