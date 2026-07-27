defmodule Boon.Printing.ItemNumber do
  @moduledoc """
  Deterministic item-number classification for printing decisions.
  """

  @kind_map %{
    "T" => :tank,
    "C" => :cabinet,
    "F" => :false_cover,
    "W" => :weld_on_lid,
    "L" => :lid
  }

  @legend %{
    tank: "Tank",
    cabinet: "Cabinet",
    false_cover: "False Cover",
    weld_on_lid: "Weld-on Lid",
    lid: "Lid"
  }

  @label_kinds [:tank, :false_cover, :weld_on_lid, :lid]

  @spec kind(String.t() | nil) :: atom | nil
  def kind(item_number) when is_binary(item_number) do
    case Regex.run(~r/^(?:90-)?86-SA-([TCFWL])/i, String.trim(item_number),
           capture: :all_but_first
         ) do
      [code] -> Map.get(@kind_map, String.upcase(code))
      _ -> nil
    end
  end

  def kind(_item_number), do: nil

  @spec legend(atom | nil) :: String.t() | nil
  def legend(kind), do: Map.get(@legend, kind)

  @spec label_item?(String.t() | nil) :: boolean
  def label_item?(item_number), do: kind(item_number) in @label_kinds

  @spec label_kind?(atom | nil) :: boolean
  def label_kind?(kind), do: kind in @label_kinds
end
