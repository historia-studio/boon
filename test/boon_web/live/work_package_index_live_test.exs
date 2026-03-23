defmodule BoonWeb.WorkPackageIndexLiveTest do
  use BoonWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Boon.Operations

  test "operator can delete a work package from the index", %{conn: conn} do
    work_package = work_package_fixture()

    {:ok, view, _html} = live(conn, ~p"/work-packages")

    assert has_element?(view, "#delete-work-package-#{work_package.id}")

    view
    |> element("#delete-work-package-#{work_package.id}")
    |> render_click()

    assert render(view) =~ "Work package deleted."
    refute has_element?(view, "#work-package-#{work_package.id}")
    refute Enum.any?(Operations.list_work_packages(), &(&1.id == work_package.id))
  end

  defp work_package_fixture do
    {:ok, work_package} =
      Operations.create_work_package_entry(%{
        number: "WP-#{System.unique_integer([:positive])}",
        purchase_orders: [
          %{
            po_number: "PO-#{System.unique_integer([:positive])}",
            order_date: ~D[2026-03-23],
            revision_date: ~D[2026-03-23],
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
