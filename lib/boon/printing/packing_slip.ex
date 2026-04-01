defmodule Boon.Printing.PackingSlip do
  @moduledoc """
  Derives packing-slip document data from a confirmed shipment.
  """

  alias Boon.Printing.PurchaseOrderReference
  alias Boon.ShippingLocation

  @sender_lines [
    "BOON-TEK INDUSTRIES LTD",
    "21111-109 AVE",
    "EDMONTON, AB, T5S 1X5"
  ]

  @spec build(map, pos_integer) :: {:ok, map} | {:error, String.t()}
  def build(shipment, shipment_index) when is_integer(shipment_index) and shipment_index > 0 do
    work_package = Map.get(shipment, :work_package)
    entries = Map.get(shipment, :entries, [])

    cond do
      is_nil(work_package) or is_nil(Map.get(work_package, :number)) ->
        {:error, "Packing slip generation requires the shipment work package to be loaded."}

      not is_list(entries) or entries == [] ->
        {:error, "Packing slip generation requires at least one shipment entry."}

      true ->
        with {:ok, ship_to} <- resolve_ship_to(entries) do
          rows = build_rows(entries)

          {:ok,
           %{
             title: "PACKING SLIP #{work_package.number}-#{shipment_index}",
             shipment_date: Map.get(shipment, :confirmed_at),
             work_package_number: work_package.number,
             ship_via: ShippingLocation.ship_via(ship_to) || "-",
             sender_lines: @sender_lines,
             ship_to_lines: ShippingLocation.address_lines(ship_to),
             ship_to: ship_to,
             rows: rows
           }}
        end
    end
  end

  defp resolve_ship_to(entries) do
    ship_tos =
      entries
      |> Enum.map(fn entry ->
        purchase_order = Map.get(entry, :purchase_order)

        case purchase_order do
          %{ship_to: ship_to} -> ship_to
          _other -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq()

    case ship_tos do
      [ship_to] ->
        {:ok, ship_to}

      [] ->
        {:error,
         "Packing slip generation requires a ship-to destination on the shipment purchase orders."}

      _many ->
        {:error,
         "Packing slip generation requires the shipment to resolve to exactly one ship-to destination."}
    end
  end

  defp build_rows(entries) do
    entries
    |> Enum.map(fn entry ->
      purchase_order = Map.get(entry, :purchase_order, %{})

      %{
        part: part_label(Map.get(entry, :pallet_type)),
        po: Map.get(entry, :po_number) || "-",
        job: purchase_order |> Map.get(:reference) |> format_jobs(),
        quantity: 1
      }
    end)
    |> Enum.reduce(%{}, fn row, acc ->
      Map.update(acc, {row.part, row.po, row.job}, row, fn existing ->
        %{existing | quantity: existing.quantity + 1}
      end)
    end)
    |> Map.values()
    |> Enum.sort_by(&{&1.po, part_sort_key(&1.part), &1.job})
  end

  defp format_jobs(reference) do
    case PurchaseOrderReference.job_numbers(reference) do
      [] -> "-"
      jobs -> Enum.join(jobs, ", ")
    end
  end

  defp part_label("tank"), do: "Tank"
  defp part_label("cabinet"), do: "Cabinet"
  defp part_label("bundle"), do: "Bundle"
  defp part_label(_other), do: "Pallet"

  defp part_sort_key("Tank"), do: 0
  defp part_sort_key("Cabinet"), do: 1
  defp part_sort_key("Bundle"), do: 2
  defp part_sort_key(_other), do: 3
end
