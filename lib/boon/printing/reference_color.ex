defmodule Boon.Printing.ReferenceColor do
  @moduledoc """
  Extracts the printable color segment from a purchase-order reference.
  """

  @spec extract(String.t() | nil) :: String.t() | nil
  def extract(reference) when is_binary(reference) do
    reference
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.at(1)
    |> normalize_color()
  end

  def extract(_reference), do: nil

  defp normalize_color(nil), do: nil

  defp normalize_color(color) do
    color
    |> String.split(~r/\s+/, trim: true)
    |> Enum.map(&normalize_word/1)
    |> Enum.join(" ")
    |> case do
      "" -> nil
      normalized -> normalized
    end
  end

  defp normalize_word(word) do
    if String.contains?(word, "/") do
      String.upcase(word)
    else
      word
      |> String.downcase()
      |> String.capitalize()
    end
  end
end
