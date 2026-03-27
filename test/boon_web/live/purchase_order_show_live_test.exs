defmodule BoonWeb.PurchaseOrderShowLiveTest do
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

  defmodule PalletTagTransportStub do
    @behaviour Boon.Printing.PalletTagTransport

    @impl true
    def print(printer_name, pdf_path, opts) do
      if notify = Keyword.get(opts, :notify) do
        pdf_header = pdf_path |> File.read!() |> binary_part(0, 8)
        send(notify, {:pallet_tag_printed, printer_name, pdf_path, pdf_header})
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
        label_transport_opts: [notify: self()],
        pallet_tag_transport_module: PalletTagTransportStub,
        pallet_tag_transport_opts: [notify: self()]
      )
    )

    on_exit(fn ->
      Application.put_env(:boon, :printing, printing_config)
    end)

    :ok
  end

  test "purchase order page shows the detail card and supports PO and line printing", %{
    conn: conn
  } do
    work_package = work_package_fixture()
    [purchase_order] = work_package.purchase_orders
    [tank_line, cabinet_line, lid_line] = purchase_order.lines

    {:ok, view, _html} =
      live(conn, ~p"/work-packages/#{work_package.id}/purchase-orders/#{purchase_order.id}")

    assert has_element?(view, "#purchase-order-detail-#{purchase_order.id}")
    assert has_element?(view, "#print-purchase-order-labels")
    assert has_element?(view, "#print-purchase-order-pallet-tags")
    assert has_element?(view, "#print-line-labels-#{tank_line.id}")
    assert has_element?(view, "#print-line-labels-#{lid_line.id}")
    assert has_element?(view, "#print-line-labels-#{cabinet_line.id}[disabled]")

    view
    |> element("#print-purchase-order-labels")
    |> render_click()

    assert_receive {:label_printed, "Label Maker", purchase_order_zpl}
    assert purchase_order_zpl =~ tank_line.item_number
    assert purchase_order_zpl =~ lid_line.item_number

    view
    |> element("#print-purchase-order-pallet-tags")
    |> render_click()

    assert_receive {:pallet_tag_printed, "Chilliwack", purchase_order_pdf_path, "%PDF-1.4"}
    assert File.exists?(purchase_order_pdf_path)

    view
    |> element("#print-line-labels-#{tank_line.id}")
    |> render_click()

    assert_receive {:label_printed, "Label Maker", line_zpl}
    assert line_zpl =~ tank_line.item_number
  end

  test "operator can edit purchase order details from the dedicated purchase order page", %{
    conn: conn
  } do
    work_package = work_package_fixture()
    [purchase_order] = work_package.purchase_orders

    {:ok, view, _html} =
      live(conn, ~p"/work-packages/#{work_package.id}/purchase-orders/#{purchase_order.id}")

    view
    |> element("#edit-purchase-order")
    |> render_click()

    assert has_element?(view, "#purchase-order-edit-form")

    params = %{
      "purchase_orders" => %{
        "0" => %{
          "po_number" => "PO-UPDATED",
          "order_date" => "2026-03-24",
          "revision_date" => "2026-03-25",
          "reference" => "2M017553, 1730, SEA FOAM",
          "ship_to" => "spruce_grove",
          "lines" => %{
            "0" => %{
              "line" => "4",
              "item_number" => "86-SA-T400",
              "ship_date" => "2026-04-14",
              "quantity" => "2"
            },
            "1" => %{
              "line" => "5",
              "item_number" => "86-SA-L400",
              "ship_date" => "2026-04-15",
              "quantity" => "1"
            }
          }
        }
      }
    }

    render_submit(view, "save_purchase_order", %{"purchase_order" => params})

    assert render(view) =~ "PO PO-UPDATED"
    assert render(view) =~ "Spruce Grove"

    updated_work_package = Operations.get_work_package!(work_package.id)
    [updated_purchase_order] = updated_work_package.purchase_orders

    assert updated_purchase_order.po_number == "PO-UPDATED"
    assert updated_purchase_order.reference == "2M017553, 1730, SEA FOAM"
    assert updated_purchase_order.ship_to == "spruce_grove"
    assert Enum.map(updated_purchase_order.lines, & &1.line) == [4, 5]

    assert Enum.map(updated_purchase_order.lines, & &1.item_number) == [
             "86-SA-T400",
             "86-SA-L400"
           ]
  end

  test "operator can delete a purchase order from the dedicated purchase order page", %{
    conn: conn
  } do
    work_package = multi_purchase_order_fixture()
    [purchase_order_to_keep, purchase_order_to_delete] = work_package.purchase_orders

    {:ok, view, _html} =
      live(
        conn,
        ~p"/work-packages/#{work_package.id}/purchase-orders/#{purchase_order_to_delete.id}"
      )

    assert has_element?(view, "#delete-purchase-order")

    view
    |> element("#delete-purchase-order")
    |> render_click()

    assert_redirect(view, ~p"/work-packages/#{work_package.id}")

    updated_work_package = Operations.get_work_package!(work_package.id)
    assert Enum.map(updated_work_package.purchase_orders, & &1.id) == [purchase_order_to_keep.id]

    refute Enum.any?(
             updated_work_package.purchase_orders,
             &(&1.id == purchase_order_to_delete.id)
           )
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

  defp multi_purchase_order_fixture do
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
              %{line: 2, item_number: "86-SA-C100", quantity: 1, ship_date: ~D[2026-04-10]}
            ]
          },
          %{
            po_number: "PO-#{System.unique_integer([:positive])}",
            order_date: ~D[2026-03-22],
            revision_date: ~D[2026-03-23],
            reference: "2M017553, 1730, 3 RAD, SEA FOAM, 84-1024300",
            ship_to: "spruce_grove",
            lines: [
              %{line: 1, item_number: "86-SA-T200", quantity: 1, ship_date: ~D[2026-04-12]},
              %{line: 2, item_number: "86-SA-C200", quantity: 1, ship_date: ~D[2026-04-12]}
            ]
          }
        ]
      })

    Operations.get_work_package!(work_package.id)
  end
end
