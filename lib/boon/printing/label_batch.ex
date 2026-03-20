defmodule Boon.Printing.LabelBatch do
  @moduledoc """
  Expands purchase-order lines into per-label print rows.
  """

  alias Boon.Printing.ItemNumber

  @spec derive_work_package(map) :: [map]
  def derive_work_package(work_package) do
    work_package.purchase_orders
    |> Enum.flat_map(&derive_purchase_order(&1, work_package.number))
  end

  @spec derive_purchase_order(map, String.t()) :: [map]
  def derive_purchase_order(purchase_order, work_package_number) do
    purchase_order.lines
    |> Enum.flat_map(fn line ->
      kind = ItemNumber.kind(line.item_number)

      if ItemNumber.label_kind?(kind) do
        Enum.map(1..line.quantity, fn copy_number ->
          %{
            item_number: line.item_number,
            item_kind: kind,
            item_label: ItemNumber.legend(kind),
            po_number: purchase_order.po_number,
            work_package_number: work_package_number,
            purchase_order_id: Map.get(purchase_order, :id),
            purchase_order_line_id: Map.get(line, :id),
            line_number: line.line,
            copy_number: copy_number
          }
        end)
      else
        []
      end
    end)
  end
end
