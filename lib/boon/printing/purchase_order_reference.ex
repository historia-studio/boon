defmodule Boon.Printing.PurchaseOrderReference do
  @moduledoc """
  Parses purchase-order references into structured fields on demand.

  Raw reference values remain unchanged in storage. This module derives
  structured data only when a caller needs to interpret the reference.
  """

  @type parsed_reference :: %{
          raw: String.t() | nil,
          color: String.t() | nil,
          job_numbers: [String.t()],
          assemblies: [String.t()],
          modifiers: [String.t()]
        }

  @job_number_regex ~r/\b[25]M0\d{5}\b/
  @assembly_codes ~w(1480 1730)
  @color_aliases %{
    "ANSI IEEE GREEN" => "ANSI/IEEE Green",
    "ANSI/IEEE GREEN" => "ANSI/IEEE Green",
    "MUNSELL GREEN" => "Munsell Green",
    "SEA FOAM" => "Sea Foam",
    "GREEN" => "Green"
  }
  @color_phrases @color_aliases |> Map.keys() |> Enum.sort_by(&String.length/1, :desc)
  @color_typos %{
    "DEA FOAM" => "SEA FOAM",
    "SEA FORAM" => "SEA FOAM"
  }
  @modifier_regex ~r/\bNO\s+RAD\b|\b\d+\s+RAD\b|\bRAD\b|\bN\/A\b/

  @spec parse(String.t() | nil) :: parsed_reference
  def parse(reference) when is_binary(reference) do
    normalized = normalize_for_matching(reference)

    %{
      raw: reference,
      color: extract_color(normalized),
      job_numbers: extract_job_numbers(normalized),
      assemblies: extract_assemblies(normalized),
      modifiers: extract_modifiers(normalized)
    }
  end

  def parse(_reference) do
    %{
      raw: nil,
      color: nil,
      job_numbers: [],
      assemblies: [],
      modifiers: []
    }
  end

  @spec color(String.t() | nil) :: String.t() | nil
  def color(reference) do
    reference
    |> parse()
    |> Map.get(:color)
  end

  @spec job_numbers(String.t() | nil) :: [String.t()]
  def job_numbers(reference) do
    reference
    |> parse()
    |> Map.get(:job_numbers)
  end

  @spec assemblies(String.t() | nil) :: [String.t()]
  def assemblies(reference) do
    reference
    |> parse()
    |> Map.get(:assemblies)
  end

  @spec modifiers(String.t() | nil) :: [String.t()]
  def modifiers(reference) do
    reference
    |> parse()
    |> Map.get(:modifiers)
  end

  @spec bundled?(String.t() | nil) :: boolean
  def bundled?(reference) do
    "1480" in assemblies(reference)
  end

  defp normalize_for_matching(reference) do
    reference
    |> String.upcase()
    |> split_fused_job_and_assembly_tokens()
    |> apply_color_typos()
    |> String.replace(~r/[^A-Z0-9\/]+/, " ")
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp split_fused_job_and_assembly_tokens(reference) do
    Enum.reduce(@assembly_codes, reference, fn assembly_code, acc ->
      Regex.replace(
        ~r/\b((?:2|5)M0\d{5})(#{assembly_code})\b/,
        acc,
        "\\1 \\2"
      )
    end)
  end

  defp apply_color_typos(reference) do
    Enum.reduce(@color_typos, reference, fn {typo, replacement}, acc ->
      String.replace(acc, typo, replacement)
    end)
  end

  defp extract_job_numbers(reference) do
    @job_number_regex
    |> Regex.scan(reference)
    |> List.flatten()
    |> Enum.uniq()
  end

  defp extract_assemblies(reference) do
    Enum.filter(@assembly_codes, fn assembly_code ->
      Regex.match?(~r/\b#{assembly_code}\b/, reference)
    end)
  end

  defp extract_modifiers(reference) do
    @modifier_regex
    |> Regex.scan(reference)
    |> List.flatten()
    |> Enum.map(&String.replace(&1, ~r/\s+/, " "))
    |> Enum.uniq()
  end

  defp extract_color(reference) do
    Enum.find_value(@color_phrases, fn phrase ->
      if Regex.match?(~r/\b#{Regex.escape(phrase)}\b/, reference) do
        Map.fetch!(@color_aliases, phrase)
      end
    end)
  end
end
