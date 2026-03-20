defmodule Boon.Printing.PalletTagPdfTest do
  use ExUnit.Case, async: true

  alias Boon.Printing.PalletTagPdf

  test "renders centered pallet tag text with an embedded QR image" do
    pdf =
      PalletTagPdf.render([
        %{
          work_package_number: "WP-10",
          po_number: "PO-2001",
          po_reference: "TRANSFORMER, ANSI/IEEE GREEN, PRIORITY",
          color: "GREEN",
          tank_item_number: "86-SA-T100",
          cabinet_item_number: "86-SA-C100",
          ship_to: "chilliwack",
          pair_number: 1,
          shipping_url: "http://DESKTOP-3BBMKIS:4000/ship?tag=token"
        }
      ])

    assert pdf =~ "%PDF-1.4"
    assert pdf =~ "/Subtype /Image"
    assert pdf =~ "/ImQR"

    refute pdf =~ "Ship URL:"
    refute pdf =~ "Work Package:"
    refute pdf =~ "PO Number:"
    refute pdf =~ "(TRANSFORMER, ANSI/IEEE GREEN, PRIORITY)"

    assert pdf =~ "(WP WP-10)"
    assert pdf =~ "(PO PO-2001)"
    assert pdf =~ "(TRANSFORMER)"
    assert pdf =~ "(GREEN)"
  end
end
