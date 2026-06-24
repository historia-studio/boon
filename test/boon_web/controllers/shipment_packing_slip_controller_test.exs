defmodule BoonWeb.ShipmentPackingSlipControllerTest do
  use BoonWeb.ConnCase, async: false

  alias Boon.Operations

  test "GET /shipments/:id/packing-slip downloads the generated packing slip PDF", %{conn: conn} do
    {shipment, work_package} = shipment_fixture()

    conn = get(conn, ~p"/shipments/#{shipment.id}/packing-slip")

    assert response(conn, 200) =~ "%PDF-1.4"
    assert get_resp_header(conn, "content-type") == ["application/pdf; charset=utf-8"]

    assert [disposition] = get_resp_header(conn, "content-disposition")

    assert disposition =~
             "attachment; filename=\"packing-slip-#{String.downcase(work_package.number)}-1.pdf\""
  end

  defp shipment_fixture do
    work_package = work_package_fixture()
    [purchase_order] = work_package.purchase_orders

    {:ok, shipment} =
      Operations.create_shipment(%{
        confirmed_at: ~U[2026-04-01 11:00:00Z],
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

    {Operations.get_shipment!(shipment.id), work_package}
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
