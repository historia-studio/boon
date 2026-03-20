defmodule Boon.ShippingLocation do
  @moduledoc """
  Canonical shipping-location metadata used by intake, parsing, and later printer routing.
  """

  @locations %{
    "chilliwack" => %{
      label: "Chilliwack",
      recipient: "CAM TRAN CO LTD.",
      street: "8841 Charles St.",
      locality: "Chilliwack, BC V2P 7H9",
      printer_paper: "chilliwack",
      pallet_tag_printer: "Chilliwack",
      label_printer: "Label Maker"
    },
    "spruce_grove" => %{
      label: "Spruce Grove",
      recipient: "CAM TRAN CO LTD.",
      street: "31 Schram Street",
      locality: "Spruce Grove, AB T7X 0G6",
      printer_paper: "spruce_grove",
      pallet_tag_printer: "Spruce Grove",
      label_printer: "Label Maker"
    }
  }

  @type value :: String.t()

  @spec values() :: [value]
  def values, do: Map.keys(@locations)

  @spec select_options() :: [{String.t(), value}]
  def select_options do
    @locations
    |> Enum.map(fn {value, location} ->
      {"#{location.label} - #{location.street}", value}
    end)
    |> Enum.sort_by(fn {label, _value} -> label end)
  end

  @spec valid_value?(term) :: boolean
  def valid_value?(value) when is_binary(value), do: Map.has_key?(@locations, value)
  def valid_value?(_value), do: false

  @spec label(value | nil) :: String.t() | nil
  def label(value) when is_binary(value), do: get_in(@locations, [value, :label])
  def label(_value), do: nil

  @spec address_lines(value | nil) :: [String.t()]
  def address_lines(value) when is_binary(value) do
    case Map.get(@locations, value) do
      nil -> []
      location -> [location.recipient, location.street, location.locality]
    end
  end

  def address_lines(_value), do: []

  @spec printer_paper(value | nil) :: String.t() | nil
  def printer_paper(value) when is_binary(value), do: get_in(@locations, [value, :printer_paper])
  def printer_paper(_value), do: nil

  @spec pallet_tag_printer(value | nil) :: String.t() | nil
  def pallet_tag_printer(value) when is_binary(value),
    do: get_in(@locations, [value, :pallet_tag_printer])

  def pallet_tag_printer(_value), do: nil

  @spec label_printer(value | nil) :: String.t() | nil
  def label_printer(value) when is_binary(value), do: get_in(@locations, [value, :label_printer])
  def label_printer(_value), do: nil

  @spec infer_from_text(String.t()) :: value | nil
  def infer_from_text(text) when is_binary(text) do
    cond do
      Regex.match?(~r/31\s+SCHRAM\s+STREET|SPR\s*UCE\s+GROVE,\s*AB\s*T7X\s*0G6/is, text) ->
        "spruce_grove"

      Regex.match?(~r/884\s*1\s+CHARLES\s+ST\.?|CHI\s*LLIWACK,\s*B\.?C\.?\s*V2P\s*7H9/is, text) ->
        "chilliwack"

      true ->
        nil
    end
  end
end
