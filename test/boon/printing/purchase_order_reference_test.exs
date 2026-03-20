defmodule Boon.Printing.PurchaseOrderReferenceTest do
  use ExUnit.Case, async: true

  alias Boon.Printing.PurchaseOrderReference
  alias Boon.Printing.ReferenceColor

  describe "parse/1" do
    test "extracts structured fields from ANSI/IEEE references" do
      parsed = PurchaseOrderReference.parse("2M017545, ANSI/IEEE GREEN, PUGET N/A")

      assert parsed.raw == "2M017545, ANSI/IEEE GREEN, PUGET N/A"
      assert parsed.job_numbers == ["2M017545"]
      assert parsed.assemblies == []
      assert parsed.modifiers == ["N/A"]
      assert parsed.color == "ANSI/IEEE Green"
    end

    test "extracts color regardless of segment order" do
      assert PurchaseOrderReference.color("2M017549, 1730, RAD, SEA FOAM") == "Sea Foam"
      assert PurchaseOrderReference.color("2M017549, SEA FOAM, 1730, RAD") == "Sea Foam"
    end

    test "extracts assemblies and modifiers from cam tran style references" do
      parsed = PurchaseOrderReference.parse("2M017553, 1730, 3 RAD, SEA FOAM, 84-1024300")

      assert parsed.job_numbers == ["2M017553"]
      assert parsed.assemblies == ["1730"]
      assert parsed.modifiers == ["3 RAD"]
      assert parsed.color == "Sea Foam"
    end

    test "corrects known color typos via the dictionary" do
      assert PurchaseOrderReference.color("2M017553, 1730, 3 RAD, DEA FOAM, 84-1024300") ==
               "Sea Foam"

      assert PurchaseOrderReference.color("2M017553, 1730, 3 RAD, SEA FORAM, 84-1024300") ==
               "Sea Foam"
    end

    test "extracts multiple job numbers from one reference" do
      parsed = PurchaseOrderReference.parse("2M017553 / 5M012345, 1730, SEA FOAM")

      assert parsed.job_numbers == ["2M017553", "5M012345"]
      assert parsed.assemblies == ["1730"]
      assert parsed.color == "Sea Foam"
    end

    test "splits fused job and assembly tokens" do
      parsed = PurchaseOrderReference.parse("2M0175531480, NO RAD, SEA FOAM")

      assert parsed.job_numbers == ["2M017553"]
      assert parsed.assemblies == ["1480"]
      assert parsed.modifiers == ["NO RAD"]
      assert parsed.color == "Sea Foam"
    end

    test "recognizes bundled references from the assembly code" do
      assert PurchaseOrderReference.bundled?("2M0175531480, NO RAD, SEA FOAM")
      refute PurchaseOrderReference.bundled?("2M017553, 1730, NO RAD, SEA FOAM")
    end

    test "returns empty structured data for invalid input" do
      assert PurchaseOrderReference.parse(nil) == %{
               raw: nil,
               color: nil,
               job_numbers: [],
               assemblies: [],
               modifiers: []
             }
    end
  end

  describe "ReferenceColor.extract/1" do
    test "delegates to the reference parser" do
      assert ReferenceColor.extract("SUBSTATION, ANSI/IEEE GREEN, WEST") == "ANSI/IEEE Green"
      assert ReferenceColor.extract("ONLY ONE SEGMENT") == nil
    end
  end
end
