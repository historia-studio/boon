defmodule Boon.Printing.PackingSlipTest do
  use ExUnit.Case, async: true

  alias Boon.Printing.PackingSlip

  test "builds an aggregated packing slip document from shipment entries" do
    shipment = %{
      confirmed_at: ~U[2026-04-01 15:30:00Z],
      entries: [
        %{
          pallet_type: "tank",
          po_number: "PO-1",
          work_package: %{number: "WP-42"},
          purchase_order: %{ship_to: "chilliwack", reference: "2M012345 1730 SEA FOAM"}
        },
        %{
          pallet_type: "tank",
          po_number: "PO-1",
          work_package: %{number: "WP-42"},
          purchase_order: %{ship_to: "chilliwack", reference: "2M012345 1730 SEA FOAM"}
        },
        %{
          pallet_type: "cabinet",
          po_number: "PO-2",
          work_package: %{number: "WP-42"},
          purchase_order: %{ship_to: "chilliwack", reference: "5M012346 ANSI/IEEE GREEN"}
        },
        %{
          pallet_type: "bundle",
          po_number: "PO-2",
          work_package: %{number: "WP-42"},
          purchase_order: %{ship_to: "chilliwack", reference: "PRIORITY"}
        }
      ]
    }

    assert {:ok, document} = PackingSlip.build(shipment, 3)

    assert document.title == "PACKING SLIP WP-42-3"
    assert document.filename_identifier == "WP-42"
    assert document.ship_via == "Bremic"
    assert document.ship_to == "chilliwack"

    assert document.sender_lines == [
             "BOON-TEK INDUSTRIES LTD",
             "21111-109 AVE",
             "EDMONTON, AB, T5S 1X5"
           ]

    assert document.ship_to_lines == [
             "CAM TRAN CO LTD.",
             "8841 Charles St.",
             "Chilliwack, BC V2P 7H9"
           ]

    assert document.rows == [
             %{part: "Tank", quantity: 2, po: "PO-1", job: "2M012345"},
             %{part: "Cabinet", quantity: 1, po: "PO-2", job: "5M012346"},
             %{part: "Bundle", quantity: 1, po: "PO-2", job: "-"}
           ]
  end

  test "builds a multi-work-package packing slip when destinations match" do
    shipment = %{
      confirmed_at: ~U[2026-04-01 15:30:00Z],
      entries: [
        %{
          pallet_type: "tank",
          po_number: "PO-1",
          work_package: %{number: "WP-10"},
          purchase_order: %{ship_to: "chilliwack", reference: "2M012345 1730 SEA FOAM"}
        },
        %{
          pallet_type: "cabinet",
          po_number: "PO-2",
          work_package: %{number: "WP-20"},
          purchase_order: %{ship_to: "chilliwack", reference: "5M012346 ANSI/IEEE GREEN"}
        }
      ]
    }

    assert {:ok, document} = PackingSlip.build(shipment, 4)

    assert document.title == "PACKING SLIP MULTI-4"
    assert document.work_package_number == "WP-10, WP-20"
    assert document.filename_identifier == "multi"
  end
end
