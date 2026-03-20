defmodule Boon.Printing.PalletTagPdf do
  @moduledoc """
  Renders pallet tags as a minimal multi-page PDF so SumatraPDF can print them.
  """

  alias Boon.ShippingLocation
  alias EQRCode.Matrix

  @page_width 612
  @page_height 792
  @font_name "Courier-Bold"
  @max_font_size 80
  @min_font_size 42
  @line_gap 12
  @qr_size 160
  @qr_y 46
  @text_top 708
  @text_bottom 246

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
      "3 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /#{@font_name} >>\nendobj\n"
    ]

    page_objects =
      tags
      |> Enum.with_index()
      |> Enum.flat_map(fn {tag, index} ->
        content = page_content(tag)
        qr_image = qr_image_object(tag)
        page_object = page_object_number(index)
        content_object = content_object_number(index)
        image_object_ref = image_object_number(index)

        [
          "#{page_object} 0 obj\n" <>
            "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 #{@page_width} #{@page_height}] " <>
            "/Resources << /Font << /F1 3 0 R >> /XObject << /ImQR #{image_object_ref} 0 R >> >> " <>
            "/Contents #{content_object} 0 R >>\n" <>
            "endobj\n",
          "#{content_object} 0 obj\n<< /Length #{byte_size(content)} >>\nstream\n#{content}\nendstream\nendobj\n",
          image_object(qr_image, image_object_ref)
        ]
      end)

    base_objects ++ page_objects
  end

  defp page_content(tag) do
    ship_to = ShippingLocation.label(tag.ship_to) || tag.ship_to || "-"

    [
      "WP #{tag.work_package_number}",
      "PO #{tag.po_number}",
      reference_prefix(tag.po_reference),
      tag.color || "-",
      tag.tank_item_number,
      tag.cabinet_item_number,
      "#{ship_to} #{tag.pair_number}"
    ]
    |> centered_text_block()
    |> Kernel.++([qr_draw_command()])
    |> Enum.join("\n")
  end

  defp text_line(x, y, size, text) do
    "BT /F1 #{size} Tf 1 0 0 1 #{x} #{y} Tm (#{escape_text(text)}) Tj ET"
  end

  defp centered_text_block(lines) do
    line_count = length(lines)
    available_height = @text_top - @text_bottom
    font_size = resolved_font_size(lines)
    block_height = line_count * font_size + max(line_count - 1, 0) * @line_gap
    start_y = @text_bottom + div(available_height - block_height, 2) + block_height - font_size

    Enum.with_index(lines)
    |> Enum.map(fn {line, index} ->
      y = start_y - index * (font_size + @line_gap)
      x = centered_x(line, font_size)
      text_line(x, y, font_size, line)
    end)
  end

  defp resolved_font_size(lines) do
    lines
    |> Enum.map(&fit_font_size/1)
    |> Enum.min(fn -> @max_font_size end)
    |> min(@max_font_size)
    |> max(@min_font_size)
  end

  defp fit_font_size(text) do
    max_width = @page_width - 64
    chars = text |> to_string() |> String.length() |> max(1)
    trunc(max_width / (chars * 0.6))
  end

  defp centered_x(text, font_size) do
    text_width = String.length(to_string(text)) * font_size * 0.6
    round((@page_width - text_width) / 2)
  end

  defp qr_draw_command do
    qr_x = div(@page_width - @qr_size, 2)

    "q #{@qr_size} 0 0 #{@qr_size} #{qr_x} #{@qr_y} cm /ImQR Do Q"
  end

  defp qr_image_object(tag) do
    matrix = EQRCode.encode(tag.shipping_url || "-")
    size = Matrix.size(matrix)

    %{
      width: size,
      height: size,
      stream: qr_pixel_stream(matrix)
    }
  end

  defp image_object(%{width: width, height: height, stream: stream}, object_number) do
    compressed = :zlib.compress(stream)

    "#{object_number} 0 obj\n" <>
      "<< /Type /XObject /Subtype /Image /Width #{width} /Height #{height} " <>
      "/ColorSpace /DeviceGray /BitsPerComponent 8 /Filter /FlateDecode " <>
      "/Length #{byte_size(compressed)} >>\nstream\n" <>
      compressed <> "\nendstream\nendobj\n"
  end

  defp qr_pixel_stream(%Matrix{matrix: matrix}) do
    matrix
    |> Tuple.to_list()
    |> Enum.map(fn row ->
      row
      |> Tuple.to_list()
      |> Enum.map(fn
        1 -> <<0>>
        _ -> <<255>>
      end)
      |> IO.iodata_to_binary()
    end)
    |> IO.iodata_to_binary()
  end

  defp escape_text(text) do
    text
    |> to_string()
    |> String.replace("\\", "\\\\")
    |> String.replace("(", "\\(")
    |> String.replace(")", "\\)")
  end

  defp reference_prefix(nil), do: "-"

  defp reference_prefix(reference) do
    reference
    |> to_string()
    |> String.split(",", parts: 2)
    |> List.first()
    |> String.trim()
    |> case do
      "" -> "-"
      prefix -> prefix
    end
  end

  defp page_object_number(index), do: 4 + index * 3
  defp content_object_number(index), do: page_object_number(index) + 1
  defp image_object_number(index), do: page_object_number(index) + 2
end
