defmodule BoonWeb.ShipmentIndexLiveTest do
  use BoonWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Boon.Operations

  test "operator can browse shipments from the index", %{conn: conn} do
    first_shipment = shipment_fixture(~U[2026-04-01 10:00:00Z])
    second_shipment = multi_work_package_shipment_fixture(~U[2026-04-01 11:00:00Z])

    {:ok, view, _html} = live(conn, ~p"/shipments")

    assert has_element?(view, "#shipments-table")
    assert has_element?(view, "#shipment-#{first_shipment.id}")
    assert has_element?(view, "#shipment-#{second_shipment.id}")
    assert render(view) =~ "WP #{hd(second_shipment.entries).work_package.number}"
    assert render(view) =~ "WP #{List.last(second_shipment.entries).work_package.number}"

    view
    |> element("#shipment-#{second_shipment.id} td:first-child")
    |> render_click()

    assert_redirect(view, ~p"/shipments/#{second_shipment.id}")
  end

  test "operator can delete a shipment from the index", %{conn: conn} do
    shipment = shipment_fixture(~U[2026-04-01 12:00:00Z])

    {:ok, view, _html} = live(conn, ~p"/shipments")

    assert has_element?(view, "#delete-shipment-#{shipment.id}")

    view
    |> element("#delete-shipment-#{shipment.id}")
    |> render_click()

    assert render(view) =~ "Shipment deleted."
    refute has_element?(view, "#shipment-#{shipment.id}")
    refute Enum.any?(Operations.list_shipments(), &(&1.id == shipment.id))
  end

  defp shipment_fixture(confirmed_at) do
    work_package = work_package_fixture()
    [purchase_order] = work_package.purchase_orders

    {:ok, shipment} =
      Operations.create_shipment(%{
        confirmed_at: confirmed_at,
        submitted_from: "BOON",
        entries: [
          %{
            pallet_tag_token: "token-#{System.unique_integer([:positive])}",
            pair_number: 1,
            pallet_type: "tank",
            po_number: purchase_order.po_number,
            tank_item_number: "86-SA-T100",
            cabinet_item_number: "86-SA-C100",
            work_package_id: work_package.id,
            purchase_order_id: purchase_order.id
          }
        ]
      })

    Operations.get_shipment!(shipment.id)
  end

  defp multi_work_package_shipment_fixture(confirmed_at) do
    first_work_package = work_package_fixture()
    second_work_package = work_package_fixture()
    [first_purchase_order] = first_work_package.purchase_orders
    [second_purchase_order] = second_work_package.purchase_orders

    {:ok, shipment} =
      Operations.create_shipment(%{
        confirmed_at: confirmed_at,
        submitted_from: "BOON",
        entries: [
          %{
            pallet_tag_token: "token-#{System.unique_integer([:positive])}",
            pair_number: 1,
            pallet_type: "tank",
            po_number: first_purchase_order.po_number,
            tank_item_number: "86-SA-T100",
            cabinet_item_number: "86-SA-C100",
            work_package_id: first_work_package.id,
            purchase_order_id: first_purchase_order.id
          },
          %{
            pallet_tag_token: "token-#{System.unique_integer([:positive])}",
            pair_number: 1,
            pallet_type: "tank",
            po_number: second_purchase_order.po_number,
            tank_item_number: "86-SA-T100",
            cabinet_item_number: "86-SA-C100",
            work_package_id: second_work_package.id,
            purchase_order_id: second_purchase_order.id
          }
        ]
      })

    Operations.get_shipment!(shipment.id)
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
