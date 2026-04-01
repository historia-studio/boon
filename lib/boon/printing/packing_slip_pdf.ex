defmodule Boon.Printing.PackingSlipPdf do
  @moduledoc """
  Renders packing slips as a minimal multi-page PDF.
  """

  @page_width 612
  @page_height 792
  @rows_per_page 22
  @title_font_size 32
  @title_y 730
  @address_block_y 680

  @spec render(map) :: binary
  def render(document) when is_map(document) do
    row_chunks =
      case Map.get(document, :rows, []) do
        [] -> [[]]
        rows -> Enum.chunk_every(rows, @rows_per_page)
      end

    objects = build_objects(document, row_chunks)

    {body, offsets} =
      Enum.reduce(objects, {"%PDF-1.4\n", []}, fn object, {acc, positions} ->
        {acc <> object, positions ++ [byte_size(acc)]}
      end)

    xref_start = byte_size(body)

    xref = [
      "xref\n0 #{length(objects) + 1}\n",
      "0000000000 65535 f \n",
      Enum.map_join(offsets, "", fn offset ->
        :io_lib.format("~10..0B 00000 n \n", [offset])
      end)
    ]

    trailer = [
      "trailer\n",
      "<< /Size #{length(objects) + 1} /Root 1 0 R >>\n",
      "startxref\n",
      Integer.to_string(xref_start),
      "\n%%EOF\n"
    ]

    IO.iodata_to_binary([body, xref, trailer])
  end

  @spec write(map, Path.t()) :: :ok | {:error, term}
  def write(document, path) do
    path
    |> Path.dirname()
    |> File.mkdir_p()

    File.write(path, render(document))
  end

  defp build_objects(document, row_chunks) do
    kids =
      row_chunks
      |> Enum.with_index()
      |> Enum.map_join(" ", fn {_rows, index} -> "#{page_object_number(index)} 0 R" end)

    base_objects = [
      "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n",
      "2 0 obj\n<< /Type /Pages /Kids [#{kids}] /Count #{length(row_chunks)} >>\nendobj\n",
      "3 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n",
      "4 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>\nendobj\n"
    ]

    page_objects =
      row_chunks
      |> Enum.with_index()
      |> Enum.flat_map(fn {rows, index} ->
        content = page_content(document, rows, index + 1, length(row_chunks))
        page_object = page_object_number(index)
        content_object = content_object_number(index)

        [
          "#{page_object} 0 obj\n" <>
            "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 #{@page_width} #{@page_height}] " <>
            "/Resources << /Font << /F1 3 0 R /F2 4 0 R >> >> " <>
            "/Contents #{content_object} 0 R >>\n" <>
            "endobj\n",
          "#{content_object} 0 obj\n<< /Length #{byte_size(content)} >>\nstream\n#{content}\nendstream\nendobj\n"
        ]
      end)

    base_objects ++ page_objects
  end

  defp page_content(document, rows, page_number, page_count) do
    left_lines = ["From" | Map.get(document, :sender_lines, [])]
    right_lines = ["Ship To" | Map.get(document, :ship_to_lines, [])]

    commands = [
      centered_text_line(
        Map.get(document, :title, "PACKING SLIP"),
        @title_font_size,
        @title_y,
        "F2"
      ),
      page_count > 1 &&
        text_line(500, @title_y + 6, 10, "Page #{page_number} of #{page_count}", "F1"),
      column_text_block(left_lines, 54, @address_block_y),
      column_text_block(right_lines, 320, @address_block_y),
      column_text_block(
        ["Shipment Date", format_date(Map.get(document, :shipment_date))],
        54,
        612
      ),
      column_text_block(["Workpackage", Map.get(document, :work_package_number, "-")], 220, 612),
      column_text_block(["Ship Via", Map.get(document, :ship_via, "-")], 386, 612),
      "0.5 w 54 548 m 558 548 l S",
      text_line(54, 532, 11, "Part", "F2"),
      text_line(196, 532, 11, "Quantity", "F2"),
      text_line(292, 532, 11, "PO", "F2"),
      text_line(400, 532, 11, "Job", "F2"),
      "0.5 w 54 522 m 558 522 l S"
    ]

    row_commands =
      rows
      |> Enum.with_index()
      |> Enum.flat_map(fn {row, index} ->
        y = 500 - index * 18

        [
          text_line(54, y, 10, Map.get(row, :part, "-"), "F1"),
          text_line(212, y, 10, Integer.to_string(Map.get(row, :quantity, 0)), "F1"),
          text_line(292, y, 10, Map.get(row, :po, "-"), "F1"),
          text_line(400, y, 10, Map.get(row, :job, "-"), "F1")
        ]
      end)

    (commands ++ row_commands)
    |> Enum.reject(&(&1 in [false, nil]))
    |> Enum.join("\n")
  end

  defp column_text_block(lines, x, start_y) do
    lines
    |> Enum.with_index()
    |> Enum.map(fn {line, index} ->
      font = if index == 0, do: "F2", else: "F1"
      text_line(x, start_y - index * 16, 11, line, font)
    end)
    |> Enum.join("\n")
  end

  defp centered_text_line(text, size, y, font) do
    width = String.length(to_string(text)) * size * 0.56
    x = round((@page_width - width) / 2)
    text_line(x, y, size, text, font)
  end

  defp text_line(x, y, size, text, font) do
    "BT /#{font} #{size} Tf 1 0 0 1 #{x} #{y} Tm (#{escape_text(text)}) Tj ET"
  end

  defp format_date(%DateTime{} = datetime), do: Calendar.strftime(datetime, "%Y-%m-%d")
  defp format_date(%Date{} = date), do: Calendar.strftime(date, "%Y-%m-%d")
  defp format_date(_other), do: "-"

  defp escape_text(text) do
    text
    |> to_string()
    |> String.replace("\\", "\\\\")
    |> String.replace("(", "\\(")
    |> String.replace(")", "\\)")
  end

  defp page_object_number(index), do: 5 + index * 2
  defp content_object_number(index), do: page_object_number(index) + 1
end
