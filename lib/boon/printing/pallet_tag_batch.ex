defmodule Boon.Printing.PalletTagBatch do
  @moduledoc """
  Derives pallet-tag rows from tank and cabinet purchase-order lines.
  """

  alias Boon.Printing.ItemNumber
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

    cond do
      tanks == [] ->
        {:error,
         "PO #{purchase_order.po_number} does not contain any tank lines for pallet tags."}

      cabinets == [] ->
        {:error,
         "PO #{purchase_order.po_number} does not contain any cabinet lines for pallet tags."}

      length(tanks) != length(cabinets) ->
        {:error,
         "PO #{purchase_order.po_number} has #{length(tanks)} tank units and #{length(cabinets)} cabinet units, so pallet tags cannot be paired deterministically."}

      true ->
        {:ok,
         build_tags(
           purchase_order,
           work_package_number,
           Enum.zip(tanks, cabinets)
         )}
    end
  end

  defp build_tags(purchase_order, work_package_number, paired_items) do
    color = ReferenceColor.extract(purchase_order.reference)

    paired_items
    |> Enum.with_index(1)
    |> Enum.flat_map(fn {{tank, cabinet}, pair_number} ->
      base_tag = %{
        tank_item_number: tank.item_number,
        cabinet_item_number: cabinet.item_number,
        po_reference: purchase_order.reference,
        color: color,
        po_number: purchase_order.po_number,
        work_package_number: work_package_number,
        ship_to: purchase_order.ship_to,
        pair_number: pair_number
      }

      if bundled_reference?(purchase_order.reference) do
        [Map.put(base_tag, :pallet_type, "bundle")]
      else
        [
          Map.put(base_tag, :pallet_type, "tank"),
          Map.put(base_tag, :pallet_type, "cabinet")
        ]
      end
    end)
  end

  defp bundled_reference?(reference) do
    reference
    |> to_string()
    |> String.contains?("1480")
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
