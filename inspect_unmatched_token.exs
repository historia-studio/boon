alias Boon.Operations
alias Boon.Shipping.PalletTagToken

{:ok, work_package} =
  Operations.create_work_package_entry(%{
    number: "WP-RT-#{System.unique_integer([:positive])}",
    purchase_orders: [
      %{
        po_number: "PO-RT-#{System.unique_integer([:positive])}",
        order_date: ~D[2026-03-20],
        revision_date: ~D[2026-03-21],
        reference: "TRANSFORMER, ANSI/IEEE GREEN, PRIORITY",
        ship_to: "chilliwack",
        lines: [
          %{line: 1, item_number: "86-SA-T100", quantity: 2, ship_date: ~D[2026-04-10]},
          %{line: 2, item_number: "86-SA-C100", quantity: 1, ship_date: ~D[2026-04-10]}
        ]
      }
    ]
  })

work_package = Operations.get_work_package!(work_package.id)
[purchase_order] = work_package.purchase_orders
token = PalletTagToken.sign(work_package.id, purchase_order.id, 2, "tank")
IO.inspect(Operations.resolve_shipping_token(token), label: "resolved")
