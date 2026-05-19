defmodule BoonWeb.ShipLiveTest do
  use BoonWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Boon.Operations
  alias Boon.Operations.Shipment
  alias Boon.Shipping.PalletTagToken

  defmodule PackingSlipTransportStub do
    @behaviour Boon.Printing.PalletTagTransport

    @impl true
    def print(printer_name, pdf_path, opts) do
      if notify = Keyword.get(opts, :notify) do
        send(notify, {:packing_slip_printed, printer_name, File.read!(pdf_path)})
      end

      Keyword.get(opts, :result, :ok)
    end
  end

  setup do
    previous = Application.get_env(:boon, :printing, [])

    Application.put_env(
      :boon,
      :printing,
      Keyword.merge(previous,
        packing_slip_transport_module: PackingSlipTransportStub,
        packing_slip_transport_opts: [notify: self()]
      )
    )

    on_exit(fn -> Application.put_env(:boon, :printing, previous) end)
    :ok
  end

  test "ship page stages a scanned pallet tag from the deep link and can confirm shipment", %{
    conn: conn
  } do
    work_package = work_package_fixture()
    [purchase_order] = work_package.purchase_orders

    token = PalletTagToken.sign(work_package.id, purchase_order.id, 1, "tank")

    {:ok, view, html} = live(conn, ~p"/ship?tag=#{token}")

    assert html =~ purchase_order.po_number
    assert html =~ "Tank 1"
    assert has_element?(view, "#submit-shipment")

    view
    |> element("#submit-shipment")
    |> render_click()

    assert render(view) =~ "confirmed with 1 pallet tags"
    assert render(view) =~ "Printed packing slip to Chilliwack"

    assert_receive {:packing_slip_printed, "Chilliwack", pdf}
    assert pdf =~ "(PACKING SLIP #{work_package.number}-1)"

    [shipment] = Ash.read!(Shipment)
    assert shipment.entry_count == 1
    assert shipment.submitted_from == "BOON"
  end

  test "ship page can manually filter, add, and remove pallet tags by PO number", %{conn: conn} do
    work_package = work_package_fixture()
    [purchase_order] = work_package.purchase_orders
    staged_row_selector = "#available-tag-#{purchase_order.id}-1-cabinet td:nth-child(1)"

    {:ok, view, _html} = live(conn, ~p"/ship")

    view
    |> element("#shipment-po-filter-form")
    |> render_change(%{"filter" => %{"po_number" => purchase_order.po_number}})

    filtered_html = render(view)
    assert filtered_html =~ purchase_order.po_number
    assert filtered_html =~ "available-tags-table"

    view
    |> element(staged_row_selector)
    |> render_click()

    assert has_element?(view, "#staged-tags-table")
    assert has_element?(view, "#submit-shipment:not([disabled])")

    view
    |> element("#remove-staged-tag-#{purchase_order.id}-1-cabinet")
    |> render_click()

    refute has_element?(view, "#staged-tags-table")
    assert has_element?(view, "#submit-shipment[disabled]")
  end

  test "shipment confirmation stays successful when packing slip printing fails", %{conn: conn} do
    previous = Application.get_env(:boon, :printing, [])

    Application.put_env(
      :boon,
      :printing,
      Keyword.merge(previous,
        packing_slip_transport_module: PackingSlipTransportStub,
        packing_slip_transport_opts: [result: {:error, "Printer offline"}]
      )
    )

    on_exit(fn -> Application.put_env(:boon, :printing, previous) end)

    work_package = work_package_fixture()
    [purchase_order] = work_package.purchase_orders

    token = PalletTagToken.sign(work_package.id, purchase_order.id, 1, "tank")

    {:ok, view, _html} = live(conn, ~p"/ship?tag=#{token}")

    view
    |> element("#submit-shipment")
    |> render_click()

    rendered = render(view)
    assert rendered =~ "confirmed with 1 pallet tags"
    assert rendered =~ "Packing slip printing failed after shipment confirmation: Printer offline"

    [shipment] = Ash.read!(Shipment)
    assert shipment.entry_count == 1
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
              %{line: 2, item_number: "86-SA-C100", quantity: 1, ship_date: ~D[2026-04-10]}
            ]
          }
        ]
      })

    Operations.get_work_package!(work_package.id)
  end
end
