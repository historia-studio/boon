defmodule Boon.Printing.PackingSlipPdfTest do
  use ExUnit.Case, async: true

  alias Boon.Printing.PackingSlipPdf

  test "renders the packing slip title, addresses, header fields, and item table" do
    pdf =
      PackingSlipPdf.render(%{
        title: "PACKING SLIP WP-10-2",
        shipment_date: ~U[2026-04-01 16:00:00Z],
        work_package_number: "WP-10",
        ship_via: "WTX",
        sender_lines: ["BOON-TEK INDUSTRIES LTD", "21111-109 AVE", "EDMONTON, AB, T5S 1X5"],
        ship_to_lines: ["CAM TRAN CO LTD.", "31 Schram Street", "Spruce Grove, AB T7X 0G6"],
        rows: [
          %{part: "Tank", quantity: 2, po: "PO-2001", job: "2M012345"},
          %{part: "Bundle", quantity: 1, po: "PO-2002", job: "5M012346"}
        ]
      })

    assert pdf =~ "%PDF-1.4"
    assert pdf =~ "(PACKING SLIP WP-10-2)"
    assert pdf =~ "/F2 32 Tf"
    assert pdf =~ "(BOON-TEK INDUSTRIES LTD)"
    assert pdf =~ "(31 Schram Street)"
    assert pdf =~ "(Shipment Date)"
    assert pdf =~ "(2026-04-01)"
    assert pdf =~ "(Workpackage)"
    assert pdf =~ "(WP-10)"
    assert pdf =~ "(Ship Via)"
    assert pdf =~ "(WTX)"
    assert pdf =~ "(Part)"
    assert pdf =~ "(Quantity)"
    assert pdf =~ "(PO)"
    assert pdf =~ "(Job)"
    assert pdf =~ "(Tank)"
    assert pdf =~ "(PO-2001)"
    assert pdf =~ "(2M012345)"
  end
end
