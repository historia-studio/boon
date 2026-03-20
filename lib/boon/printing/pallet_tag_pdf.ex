defmodule Boon.Printing.PalletTagPdf do
  @moduledoc """
  Renders pallet tags as a minimal multi-page PDF so SumatraPDF can print them.
  """

  alias Boon.ShippingLocation

  @page_width 612
  @page_height 792

  @spec render([map]) :: binary
  def render(tags) when is_list(tags) and tags != [] do
    objects = build_objects(tags)

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

  def render([]), do: raise(ArgumentError, "at least one pallet tag is required")

  @spec write([map], Path.t()) :: :ok | {:error, term}
  def write(tags, path) do
    path
    |> Path.dirname()
    |> File.mkdir_p()

    File.write(path, render(tags))
  end

  defp build_objects(tags) do
    kids =
      tags
      |> Enum.with_index()
      |> Enum.map_join(" ", fn {_tag, index} -> "#{page_object_number(index)} 0 R" end)

    base_objects = [
      "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n",
      "2 0 obj\n<< /Type /Pages /Kids [#{kids}] /Count #{length(tags)} >>\nendobj\n",
      "3 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n"
    ]

    page_objects =
      tags
      |> Enum.with_index()
      |> Enum.flat_map(fn {tag, index} ->
        content = page_content(tag)
        page_object = page_object_number(index)
        content_object = content_object_number(index)

        [
          "#{page_object} 0 obj\n" <>
            "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 #{@page_width} #{@page_height}] " <>
            "/Resources << /Font << /F1 3 0 R >> >> /Contents #{content_object} 0 R >>\n" <>
            "endobj\n",
          "#{content_object} 0 obj\n<< /Length #{byte_size(content)} >>\nstream\n#{content}\nendstream\nendobj\n"
        ]
      end)

    base_objects ++ page_objects
  end

  defp page_content(tag) do
    ship_to = ShippingLocation.label(tag.ship_to) || tag.ship_to || "-"

    [
      text_line(72, 740, 26, "PALLET TAG"),
      text_line(72, 700, 18, "Work Package: #{tag.work_package_number}"),
      text_line(72, 670, 16, "PO Number: #{tag.po_number}"),
      text_line(72, 640, 16, "PO Reference: #{tag.po_reference || "-"}"),
      text_line(72, 610, 16, "Color: #{tag.color || "-"}"),
      text_line(72, 560, 18, "Tank Item Number: #{tag.tank_item_number}"),
      text_line(72, 530, 18, "Cabinet Item Number: #{tag.cabinet_item_number}"),
      text_line(72, 490, 16, "Ship To: #{ship_to}"),
      text_line(72, 460, 16, "Pallet Pair: #{tag.pair_number}"),
      text_line(72, 430, 10, "Ship URL: #{tag.shipping_url || "-"}")
    ]
    |> Enum.join("\n")
  end

  defp text_line(x, y, size, text) do
    "BT /F1 #{size} Tf 1 0 0 1 #{x} #{y} Tm (#{escape_text(text)}) Tj ET"
  end

  defp escape_text(text) do
    text
    |> to_string()
    |> String.replace("\\", "\\\\")
    |> String.replace("(", "\\(")
    |> String.replace(")", "\\)")
  end

  defp page_object_number(index), do: 4 + index * 2
  defp content_object_number(index), do: page_object_number(index) + 1
end
