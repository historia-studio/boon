defmodule Boon.PDF.CamTranTextParser do
  @moduledoc """
  Parses normalized text extracted from the CAM TRAN CO. LTD. purchase-order PDF
  layout into the existing manual-intake shape.
  """

  @behaviour Boon.PDF.IntakeParser

  alias Boon.ShippingLocation

  @line_pattern ~r/^\s*(\d+)\s+(.+?)\s+(\d{2}\/\d{2}\/\d{4})\s+([\d,]+(?:\.\d+)?)\s+(?:[\d,]+(?:\.\d+)?\s+){1,2}[\d,]+(?:\.\d+)?\s*$/
  @impl true
  def parse_purchase_order(path) do
    with {:ok, text} <- File.read(path) do
      parse(text)
    else
      {:error, reason} -> {:error, Exception.message(reason)}
    end
  end

  @spec parse(String.t()) :: {:ok, Boon.PDF.IntakeParser.parse_result()} | {:error, String.t()}
  def parse(text) when is_binary(text) do
    normalized_text = normalize_text(text)

    with {:ok, po_number} <- extract_po_number(normalized_text),
         {:ok, lines} <- extract_lines(normalized_text) do
      {order_date, order_date_warning} =
        extract_optional_date(
          normalized_text,
          ~r/Order\s+Date\s*:?\s*(\d{2}\/\d{2}\/\d{4})/i,
          "Order date"
        )

      {revision_date, revision_date_warning} = extract_optional_revision_date(normalized_text)

      {reference, reference_warning} = extract_optional_reference(normalized_text)
      {ship_to, ship_to_warning} = extract_optional_ship_to(normalized_text)

      warnings =
        [order_date_warning, revision_date_warning, reference_warning, ship_to_warning]
        |> Enum.reject(&is_nil/1)

      {:ok,
       %{
         purchase_orders: [
           %{
             po_number: po_number,
             order_date: order_date,
             revision_date: revision_date,
             reference: reference,
             ship_to: ship_to,
             lines: lines
           }
         ],
         warnings: warnings
       }}
    end
  end

  defp normalize_text(text) do
    text
    |> String.replace("\r\n", "\n")
    |> String.replace("\r", "\n")
    |> String.replace(~r/[\x{00A0}\t]+/u, " ")
    |> String.replace(~r/ +/u, " ")
  end

  defp extract_po_number(text) do
    case Regex.run(~r/Purchase\s+Order\s+Number\s*:?\s*(\d+)/i, text, capture: :all_but_first) do
      [po_number] -> {:ok, po_number}
      _ -> {:error, "Could not find a purchase order number in the uploaded PDF."}
    end
  end

  defp extract_optional_date(text, pattern, label) do
    case Regex.run(pattern, text, capture: :all_but_first) do
      [value] ->
        case parse_mmddyyyy(value) do
          {:ok, date} -> {date, nil}
          :error -> {nil, "#{label} was detected but could not be parsed."}
        end

      _ ->
        {nil, "#{label} was not detected and will need manual review."}
    end
  end

  defp extract_optional_reference(text) do
    case extract_reference_value(text) do
      reference when is_binary(reference) ->
        cleaned_reference =
          reference
          |> String.replace(~r/\s+/u, " ")
          |> String.trim()

        if cleaned_reference == "" do
          {nil, "Reference was blank after normalization and will need manual review."}
        else
          {cleaned_reference, nil}
        end

      _ ->
        {nil, "Reference was not detected and will need manual review."}
    end
  end

  defp extract_optional_ship_to(text) do
    case ShippingLocation.infer_from_text(text) do
      nil -> {nil, "Ship To was not detected and will need manual review."}
      ship_to -> {ship_to, nil}
    end
  end

  defp extract_reference_value(text) do
    extract_header_reference_value(text)
  end

  defp extract_header_reference_value(text) do
    case Regex.run(
           ~r/Responsibility\s+Reference\s+Carrier\s+Account\s+Payment\s+Terms.*?\n\s*\S+\s+(.+?)\s+\d+\s+DAYS/is,
           text,
           capture: :all_but_first
         ) ||
           Regex.run(
             ~r/Reference\s+(.*?)(?:\s+Carrier\s+Account|\s+Payment\s+Terms|\n\s*\d+\s+.+?$)/is,
             text,
             capture: :all_but_first
           ) do
      [reference] -> reference
      _ -> nil
    end
  end

  defp extract_optional_revision_date(text) do
    case Regex.run(~r/Revision\s+Date\s*:?\s*(\d{2}\/\d{2}\/\d{4})/i, text,
           capture: :all_but_first
         ) do
      [value] ->
        case parse_mmddyyyy(value) do
          {:ok, date} -> {date, nil}
          :error -> {nil, "Revision date was detected but could not be parsed."}
        end

      _ ->
        case Regex.run(
               ~r/Order\s+Date\s+Revision\s+Date.*?\n\s*\d{2}\/\d{2}\/\d{4}\s+(\d{2}\/\d{2}\/\d{4})/is,
               text,
               capture: :all_but_first
             ) do
          [value] ->
            case parse_mmddyyyy(value) do
              {:ok, date} -> {date, nil}
              :error -> {nil, "Revision date was detected but could not be parsed."}
            end

          _ ->
            {nil, "Revision date was not detected and will need manual review."}
        end
    end
  end

  defp extract_lines(text) do
    lines =
      text
      |> String.split("\n")
      |> Enum.map(&String.trim/1)
      |> Enum.filter(&(&1 != ""))
      |> Enum.reduce([], fn line, parsed_lines ->
        case Regex.run(@line_pattern, line, capture: :all_but_first) do
          [line_number, item_number, ship_date, quantity] ->
            case {parse_positive_integer(line_number), parse_mmddyyyy(ship_date),
                  parse_quantity(quantity)} do
              {{:ok, parsed_line_number}, {:ok, parsed_ship_date}, {:ok, parsed_quantity}} ->
                [
                  %{
                    line: parsed_line_number,
                    item_number: normalize_item_number(item_number),
                    ship_date: parsed_ship_date,
                    quantity: parsed_quantity
                  }
                  | parsed_lines
                ]

              _ ->
                parsed_lines
            end

          _ ->
            parsed_lines
        end
      end)
      |> Enum.reverse()

    if lines == [] do
      {:error, "Could not find any line items in the uploaded PDF."}
    else
      {:ok, lines}
    end
  end

  defp normalize_item_number(value) do
    value
    |> String.replace(~r/\s+/u, " ")
    |> String.trim()
  end

  defp parse_mmddyyyy(value) do
    case String.split(value, "/") do
      [month, day, year] ->
        with {parsed_month, ""} <- Integer.parse(month),
             {parsed_day, ""} <- Integer.parse(day),
             {parsed_year, ""} <- Integer.parse(year),
             {:ok, date} <- Date.new(parsed_year, parsed_month, parsed_day) do
          {:ok, date}
        else
          _ -> :error
        end

      _ ->
        :error
    end
  end

  defp parse_positive_integer(value) do
    case Integer.parse(value) do
      {parsed_value, ""} when parsed_value > 0 -> {:ok, parsed_value}
      _ -> :error
    end
  end

  defp parse_quantity(value) do
    normalized = String.replace(value, ",", "")

    case Float.parse(normalized) do
      {parsed_value, ""} when parsed_value > 0 and parsed_value == trunc(parsed_value) ->
        {:ok, trunc(parsed_value)}

      _ ->
        :error
    end
  end
end
