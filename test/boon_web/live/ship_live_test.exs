defmodule BoonWeb.ShipLiveTest do
  use BoonWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Boon.Operations
  alias Boon.Operations.Shipment
  alias Boon.Shipping.PalletTagToken

  test "ship page stages a scanned pallet tag from the deep link and can confirm shipment", %{
    conn: conn
  } do
    work_package = work_package_fixture()
    [purchase_order] = work_package.purchase_orders

    token = PalletTagToken.sign(work_package.id, purchase_order.id, 1)

    {:ok, view, html} = live(conn, ~p"/ship?tag=#{token}")

    assert html =~ purchase_order.po_number
    assert has_element?(view, "#submit-shipment")

    view
    |> element("#submit-shipment")
    |> render_click()

    assert render(view) =~ "confirmed with 1 pallet tags"

    [shipment] = Ash.read!(Shipment)
    assert shipment.entry_count == 1
    assert shipment.submitted_from == "DESKTOP-3BBMKIS"
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
