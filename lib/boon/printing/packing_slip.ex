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
    entries = Map.get(shipment, :entries, [])

    cond do
      not is_list(entries) or entries == [] ->
        {:error, "Packing slip generation requires at least one shipment entry."}

      true ->
        with {:ok, work_package_numbers} <- resolve_work_package_numbers(entries),
             {:ok, ship_to} <- resolve_ship_to(entries) do
          rows = build_rows(entries)
          work_package_label = Enum.join(work_package_numbers, ", ")
          filename_identifier = packing_slip_filename_identifier(work_package_numbers)

          {:ok,
           %{
             title: "PACKING SLIP #{packing_slip_title_identifier(work_package_numbers)}-#{shipment_index}",
             shipment_date: Map.get(shipment, :confirmed_at),
             work_package_number: work_package_label,
             filename_identifier: filename_identifier,
             ship_via: ShippingLocation.ship_via(ship_to) || "-",
             sender_lines: @sender_lines,
             ship_to_lines: ShippingLocation.address_lines(ship_to),
             ship_to: ship_to,
             rows: rows
           }}
        end
    end
  end

  defp resolve_work_package_numbers(entries) do
    entries
    |> Enum.reduce_while({:ok, []}, fn entry, {:ok, numbers} ->
      case Map.get(entry, :work_package) do
        %{number: number} when is_binary(number) and number != "" ->
          {:cont, {:ok, [number | numbers]}}

        _other ->
          {:halt,
           {:error,
            "Packing slip generation requires the shipment entry work packages to be loaded."}}
      end
    end)
    |> case do
      {:ok, numbers} ->
        {:ok, numbers |> Enum.uniq() |> Enum.sort()}

      {:error, error} ->
        {:error, error}
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

  defp packing_slip_title_identifier([work_package_number]), do: work_package_number
  defp packing_slip_title_identifier(_work_package_numbers), do: "MULTI"

  defp packing_slip_filename_identifier([work_package_number]), do: work_package_number
  defp packing_slip_filename_identifier(_work_package_numbers), do: "multi"
end
