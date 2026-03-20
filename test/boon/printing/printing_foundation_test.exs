defmodule Boon.Printing.PrintingFoundationTest do
  use ExUnit.Case, async: true

  alias Boon.Printing.{ItemNumber, LabelBatch, LabelZpl, PalletTagBatch, ReferenceColor}
  alias Boon.ShippingLocation

  describe "item-number helpers" do
    test "classifies supported item kinds and label eligibility" do
      assert ItemNumber.kind("86-SA-T100") == :tank
      assert ItemNumber.kind("86-SA-C200") == :cabinet
      assert ItemNumber.kind("86-SA-F300") == :false_cover
      assert ItemNumber.kind("86-SA-W400") == :weld_on_lid
      assert ItemNumber.kind("86-SA-L500") == :lid
      assert ItemNumber.kind("86-SA-X999") == nil

      assert ItemNumber.label_item?("86-SA-T100")
      refute ItemNumber.label_item?("86-SA-C200")
    end
  end

  describe "reference color extraction" do
    test "normalizes the color segment from the PO reference" do
      assert ReferenceColor.extract("SUBSTATION, ANSI/IEEE GREEN, WEST") == "ANSI/IEEE Green"
      assert ReferenceColor.extract("ONLY ONE SEGMENT") == nil
    end
  end

  describe "label batch derivation" do
    test "expands label-eligible lines by quantity" do
      purchase_order = %{
        id: "po-1",
        po_number: "PO-100",
        lines: [
          %{id: "line-1", line: 1, item_number: "86-SA-T100", quantity: 2},
          %{id: "line-2", line: 2, item_number: "86-SA-C100", quantity: 2},
          %{id: "line-3", line: 3, item_number: "86-SA-L100", quantity: 1}
        ]
      }

      labels = LabelBatch.derive_purchase_order(purchase_order, "WP-100")

      assert Enum.map(labels, & &1.item_number) == ["86-SA-T100", "86-SA-T100", "86-SA-L100"]
      assert Enum.map(labels, & &1.copy_number) == [1, 2, 1]
      assert Enum.map(labels, & &1.item_kind) == [:tank, :tank, :lid]
    end
  end

  describe "pallet tag derivation" do
    test "derives separate tank and cabinet pallet tags for non-1480 references" do
      purchase_order = %{
        po_number: "PO-200",
        reference: "TRANSFORMER, ANSI/IEEE GREEN, PRIORITY",
        ship_to: "chilliwack",
        lines: [
          %{line: 1, item_number: "86-SA-T100", quantity: 2},
          %{line: 2, item_number: "86-SA-C100", quantity: 2}
        ]
      }

      assert {:ok, tags} = PalletTagBatch.derive_purchase_order(purchase_order, "WP-200")
      assert length(tags) == 4
      assert Enum.all?(tags, &(&1.tank_item_number == "86-SA-T100"))
      assert Enum.all?(tags, &(&1.cabinet_item_number == "86-SA-C100"))
      assert Enum.all?(tags, &(&1.color == "ANSI/IEEE Green"))
      assert Enum.map(tags, & &1.pair_number) == [1, 1, 2, 2]
      assert Enum.map(tags, & &1.pallet_type) == ["tank", "cabinet", "tank", "cabinet"]
    end

    test "keeps bundled pallet tags for 1480 references" do
      purchase_order = %{
        po_number: "PO-200",
        reference: "TRANSFORMER 1480, ANSI/IEEE GREEN, PRIORITY",
        ship_to: "chilliwack",
        lines: [
          %{line: 1, item_number: "86-SA-T100", quantity: 2},
          %{line: 2, item_number: "86-SA-C100", quantity: 2}
        ]
      }

      assert {:ok, tags} = PalletTagBatch.derive_purchase_order(purchase_order, "WP-200")
      assert length(tags) == 2
      assert Enum.map(tags, & &1.pair_number) == [1, 2]
      assert Enum.map(tags, & &1.pallet_type) == ["bundle", "bundle"]
    end

    test "returns an error when tank and cabinet quantities do not match" do
      purchase_order = %{
        po_number: "PO-201",
        reference: "TRANSFORMER, ANSI/IEEE GREEN, PRIORITY",
        ship_to: "spruce_grove",
        lines: [
          %{line: 1, item_number: "86-SA-T100", quantity: 2},
          %{line: 2, item_number: "86-SA-C100", quantity: 1}
        ]
      }

      assert {:error, message} = PalletTagBatch.derive_purchase_order(purchase_order, "WP-201")
      assert message =~ "cannot be paired deterministically"
    end
  end

  describe "printer helpers" do
    test "resolves configured printer names by ship-to location" do
      assert ShippingLocation.label_printer("chilliwack") == "Label Maker"
      assert ShippingLocation.pallet_tag_printer("chilliwack") == "Chilliwack"
      assert ShippingLocation.pallet_tag_printer("spruce_grove") == "Spruce Grove"
    end
  end

  describe "zpl rendering" do
    test "renders a batch of 3x1 labels containing only item numbers" do
      zpl =
        LabelZpl.render_batch([
          %{item_number: "86-SA-T100"},
          %{item_number: "86-SA-L100"}
        ])

      assert zpl =~ "^PW609"
      assert zpl =~ "^FD86-SA-T100^FS"
      assert zpl =~ "^FD86-SA-L100^FS"
      assert String.split(zpl, "^XA") |> length() == 3
    end
  end
end
