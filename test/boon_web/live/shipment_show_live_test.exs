defmodule BoonWeb.ShipmentShowLiveTest do
  use BoonWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Boon.Operations

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
    printing_config = Application.get_env(:boon, :printing, [])

    Application.put_env(
      :boon,
      :printing,
      Keyword.merge(printing_config,
        packing_slip_transport_module: PackingSlipTransportStub,
        packing_slip_transport_opts: [notify: self()]
      )
    )

    on_exit(fn ->
      Application.put_env(:boon, :printing, printing_config)
    end)

    :ok
  end

  test "shipment detail renders and can reprint the packing slip", %{conn: conn} do
    shipment = shipment_fixture()
    work_package = hd(shipment.entries).work_package

    {:ok, view, _html} = live(conn, ~p"/shipments/#{shipment.id}")

    assert has_element?(view, "#reprint-packing-slip")

    assert has_element?(
             view,
             "#download-packing-slip[href='/shipments/#{shipment.id}/packing-slip']"
           )

    assert has_element?(view, "#shipment-entries-table")
    assert has_element?(view, "#shipment-entry-#{hd(shipment.entries).id}")

    view
    |> element("#reprint-packing-slip")
    |> render_click()

    assert_receive {:packing_slip_printed, "Chilliwack", pdf}
    assert pdf =~ "PACKING SLIP #{work_package.number}-1"
    assert render(view) =~ "Reprinted packing slip to Chilliwack."
  end

  test "shipment detail shows linked work package cells for multi-work-package shipments", %{conn: conn} do
    shipment = multi_work_package_shipment_fixture()
    first_work_package = hd(shipment.entries).work_package
    second_work_package = List.last(shipment.entries).work_package

    {:ok, view, _html} = live(conn, ~p"/shipments/#{shipment.id}")

    assert has_element?(
             view,
             "#shipment-entries-table a[href='/work-packages/#{first_work_package.id}']"
           )

    assert has_element?(
             view,
             "#shipment-entries-table a[href='/work-packages/#{second_work_package.id}']"
           )

    refute render(view) =~ "Delete ShipmentWork Package"
  end

  test "shipment detail shows a flash when reprint fails", %{conn: conn} do
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

    shipment = shipment_fixture()

    {:ok, view, _html} = live(conn, ~p"/shipments/#{shipment.id}")

    view
    |> element("#reprint-packing-slip")
    |> render_click()

    assert render(view) =~ "Packing slip reprint failed: Printer offline"
  end

  test "shipment detail can delete the shipment", %{conn: conn} do
    shipment = shipment_fixture()

    {:ok, view, _html} = live(conn, ~p"/shipments/#{shipment.id}")

    assert has_element?(view, "#delete-shipment")

    view
    |> element("#delete-shipment")
    |> render_click()

    assert_redirect(view, ~p"/shipments")
    refute Enum.any?(Operations.list_shipments(), &(&1.id == shipment.id))
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
          },
          %{
            pallet_tag_token: "token-#{System.unique_integer([:positive])}",
            pair_number: 1,
            pallet_type: "cabinet",
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

  defp multi_work_package_shipment_fixture do
    first_work_package = work_package_fixture()
    second_work_package = work_package_fixture()
    [first_purchase_order] = first_work_package.purchase_orders
    [second_purchase_order] = second_work_package.purchase_orders

    {:ok, shipment} =
      Operations.create_shipment(%{
        confirmed_at: ~U[2026-04-01 11:00:00Z],
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
