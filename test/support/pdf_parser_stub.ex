defmodule Boon.PDF.ParserStub do
  @behaviour Boon.PDF.IntakeParser

  @impl true
  def parse_purchase_order(_path) do
    {:ok,
     %{
       purchase_orders: [
         %{
           po_number: "63129",
           order_date: ~D[2026-03-12],
           revision_date: ~D[2026-03-12],
           reference: "2M017545, ANSI/IEEE GREEN, PUGET N/A",
           lines: [
             %{
               line: 1,
               item_number: "86-SA-T1G50064295",
               ship_date: ~D[2026-03-19],
               quantity: 2
             },
             %{
               line: 2,
               item_number: "86-SA-F1G50053079",
               ship_date: ~D[2026-03-19],
               quantity: 2
             }
           ]
         }
       ],
       warnings: ["Imported with the test parser stub."]
     }}
  end
end
