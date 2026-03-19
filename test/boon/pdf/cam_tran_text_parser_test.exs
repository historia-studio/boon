defmodule Boon.PDF.CamTranTextParserTest do
  use ExUnit.Case, async: true

  alias Boon.PDF.CamTranTextParser

  test "parses cam tran purchase order text into intake attrs" do
    text = """
    Purchase Order
    Purchase Order Number : 63129
    Page Number: 1 of 1
    Order Date : 03/12/2026
    Vendor Number : CBOO01
    Currency : CAD

    Order Date Revision Date Ship Via F.O.B. Currency
    03/12/2026 03/12/2026 CAD
    Responsibility Reference Carrier Account Payment Terms
    PRIYAM 2M017545, ANSI/IEEE GREEN, PUGET N/A 30 DAYS

    Line/ Item Number / Description/ Vendor Item Number / Ship Date Quantity Ord UOM Unit Cost Extended Cost
    1 86-SA-T1G50064295 03/19/2026 2.00 2,775.00 5,550.00
    2 86-SA-F1G50053079 03/19/2026 2.00 112.50 225.00
    3 86-SA-C1G50062076 03/19/2026 2.00 500.00 1,000.00
    4 86-SA-W1G50066707 03/19/2026 2.00 112.50 225.00
    5 PAINT 03/19/2026 2.00 150.00 300.00
    """

    assert {:ok, %{purchase_orders: [purchase_order], warnings: warnings}} =
             CamTranTextParser.parse(text)

    assert purchase_order.po_number == "63129"
    assert purchase_order.order_date == ~D[2026-03-12]
    assert purchase_order.revision_date == ~D[2026-03-12]
    assert purchase_order.reference == "2M017545, ANSI/IEEE GREEN, PUGET N/A"
    assert length(purchase_order.lines) == 5

    assert Enum.at(purchase_order.lines, 0) == %{
             line: 1,
             item_number: "86-SA-T1G50064295",
             ship_date: ~D[2026-03-19],
             quantity: 2
           }

    assert warnings == []
  end
end
