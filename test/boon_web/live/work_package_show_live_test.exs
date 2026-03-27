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

  test "work package screen prints labels for work package, purchase order, and line", %{
    conn: conn
  } do
    work_package = work_package_fixture()

    {:ok, view, _html} = live(conn, ~p"/work-packages/#{work_package.id}")

    assert has_element?(view, "#print-work-package-labels")
    assert has_element?(view, "#purchase-orders-table")
    refute render(view) =~ "Purchase Order Detail"

    view
    |> element("#print-work-package-labels")
    |> render_click()

    assert_receive {:label_printed, "Label Maker", work_package_zpl}
    assert work_package_zpl =~ "86-SA-T100"
    assert work_package_zpl =~ "86-SA-L100"
    assert render(view) =~ "Printed 2 labels to Label Maker."
  end

  test "work package screen prints pallet tags for the full work package", %{conn: conn} do
    work_package = work_package_fixture()

    {:ok, view, _html} = live(conn, ~p"/work-packages/#{work_package.id}")

    assert has_element?(view, "#print-work-package-pallet-tags")

    view
    |> element("#print-work-package-pallet-tags")
    |> render_click()

    assert_receive {:pallet_tag_printed, "Chilliwack", work_package_pdf_path, "%PDF-1.4"}
    assert File.exists?(work_package_pdf_path)
    assert render(view) =~ "Printed 2 pallet tags to Chilliwack."
  end

  test "operator can delete a work package from the detail screen", %{conn: conn} do
    work_package = work_package_fixture()

    {:ok, view, _html} = live(conn, ~p"/work-packages/#{work_package.id}")

    assert has_element?(view, "#delete-work-package")

    view
    |> element("#delete-work-package")
    |> render_click()

    assert_redirect(view, ~p"/work-packages")
    refute Enum.any?(Operations.list_work_packages(), &(&1.id == work_package.id))
  end

  test "operator can open a purchase order page from the table", %{conn: conn} do
    work_package = multi_purchase_order_fixture()
    [_first_purchase_order, second_purchase_order] = work_package.purchase_orders

    {:ok, view, _html} = live(conn, ~p"/work-packages/#{work_package.id}")

    assert has_element?(view, "#purchase-order-row-#{second_purchase_order.id}")

    view
    |> element("#purchase-order-row-#{second_purchase_order.id} td:first-child")
    |> render_click()

    assert_redirect(
      view,
      ~p"/work-packages/#{work_package.id}/purchase-orders/#{second_purchase_order.id}"
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
