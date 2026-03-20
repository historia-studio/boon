defmodule Boon.Printing.LabelZpl do
  @moduledoc """
  Renders 3x1 label jobs as ZPL.
  """

  @default_width 609
  @default_length 203
  @default_font_height 84
  @default_font_width 58

  @spec render_label(String.t(), keyword) :: String.t()
  def render_label(item_number, opts \\ []) do
    width = Keyword.get(opts, :width, @default_width)
    length = Keyword.get(opts, :length, @default_length)
    font_height = Keyword.get(opts, :font_height, @default_font_height)
    font_width = Keyword.get(opts, :font_width, @default_font_width)

    [
      "^XA",
      "^PW#{width}",
      "^LL#{length}",
      "^LH0,0",
      "^FO20,52",
      "^A0N,#{font_height},#{font_width}",
      "^FD#{escape(item_number)}^FS",
      "^XZ"
    ]
    |> Enum.join("\n")
  end

  @spec render_batch([map], keyword) :: String.t()
  def render_batch(labels, opts \\ []) do
    labels
    |> Enum.map(&render_label(&1.item_number, opts))
    |> Enum.join("\n")
  end

  defp escape(item_number) do
    item_number
    |> to_string()
    |> String.replace("^", " ")
    |> String.replace("~", "-")
  end
end
