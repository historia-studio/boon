defmodule Boon.Printing.PalletTagBatch do
  @moduledoc """
  Derives pallet-tag rows from tank and cabinet purchase-order lines.
  """

  alias Boon.Printing.ItemNumber
  alias Boon.Printing.PurchaseOrderReference
  alias Boon.Printing.ReferenceColor

  @spec derive_work_package(map) :: {:ok, [map]} | {:error, [String.t()]}
  def derive_work_package(work_package) do
    work_package.purchase_orders
    |> Enum.reduce({:ok, []}, fn purchase_order, {:ok, tags} ->
      case derive_purchase_order(purchase_order, work_package.number) do
        {:ok, purchase_order_tags} -> {:ok, tags ++ purchase_order_tags}
        {:error, error} -> {:error, [error]}
      end
    end)
  end

  @spec derive_purchase_order(map, String.t()) :: {:ok, [map]} | {:error, String.t()}
  def derive_purchase_order(purchase_order, work_package_number) do
    tanks = expanded_items(purchase_order.lines, :tank)
    cabinets = expanded_items(purchase_order.lines, :cabinet)

    if tanks == [] and cabinets == [] do
      {:error,
       "PO #{purchase_order.po_number} does not contain any tank or cabinet lines for pallet tags."}
    else
      {:ok,
       build_tags(
         purchase_order,
         work_package_number,
         pair_items(tanks, cabinets)
       )}
    end
  end

  defp build_tags(purchase_order, work_package_number, paired_items) do
    color = ReferenceColor.extract(purchase_order.reference)

    paired_items
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {%{tank: tank, cabinet: cabinet}, pair_number} ->
      base_tag = %{
        tank_item_number: item_number_or_blank(tank),
        cabinet_item_number: item_number_or_blank(cabinet),
        po_reference: purchase_order.reference,
        color: color,
        po_number: purchase_order.po_number,
        work_package_number: work_package_number,
        ship_to: purchase_order.ship_to,
        pair_number: pair_number
      }

      build_unit_tags(base_tag, purchase_order.reference, tank, cabinet)
    end)
  end

  defp build_unit_tags(base_tag, reference, tank, cabinet) do
    cond do
      bundled_reference?(reference) and tank != nil and cabinet != nil ->
        [Map.put(base_tag, :pallet_type, "bundle")]

      true ->
        []
        |> maybe_add_tag(base_tag, tank, "tank")
        |> maybe_add_tag(base_tag, cabinet, "cabinet")
    end
  end

  defp maybe_add_tag(tags, _base_tag, nil, _pallet_type), do: tags

  defp maybe_add_tag(tags, base_tag, _item, pallet_type) do
    tags ++ [Map.put(base_tag, :pallet_type, pallet_type)]
  end

  defp pair_items(tanks, cabinets) do
    pair_count = min(length(tanks), length(cabinets))

    paired_tanks = Enum.take(tanks, pair_count)
    paired_cabinets = Enum.take(cabinets, pair_count)
    leftover_tanks = Enum.drop(tanks, pair_count)
    leftover_cabinets = Enum.drop(cabinets, pair_count)

    Enum.zip_with(paired_tanks, paired_cabinets, fn tank, cabinet -> %{tank: tank, cabinet: cabinet} end) ++
      Enum.map(leftover_tanks, &%{tank: &1, cabinet: nil}) ++
      Enum.map(leftover_cabinets, &%{tank: nil, cabinet: &1})
  end

  defp item_number_or_blank(nil), do: ""
  defp item_number_or_blank(item), do: item.item_number

  defp bundled_reference?(reference) do
    PurchaseOrderReference.bundled?(reference)
  end

  defp expanded_items(lines, required_kind) do
    lines
    |> Enum.flat_map(fn line ->
      if ItemNumber.kind(line.item_number) == required_kind do
        Enum.map(1..line.quantity, fn copy_number ->
          %{
            item_number: line.item_number,
            line_number: line.line,
            copy_number: copy_number
          }
        end)
      else
        []
      end
    end)
    |> Enum.sort_by(&{&1.line_number, &1.copy_number, &1.item_number})
  end
end
