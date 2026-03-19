defmodule Boon.PDF.IntakeParser do
  @moduledoc """
  Behaviour and entry point for purchase-order PDF extraction.

  The active adapter is configured via `:boon, :pdf_intake_parser` so the
  upload flow can be tested without host OCR binaries.
  """

  @type line_attrs :: %{
          line: pos_integer(),
          item_number: String.t(),
          ship_date: Date.t() | nil,
          quantity: pos_integer()
        }

  @type purchase_order_attrs :: %{
          po_number: String.t(),
          order_date: Date.t() | nil,
          revision_date: Date.t() | nil,
          reference: String.t() | nil,
          ship_to: String.t() | nil,
          lines: [line_attrs]
        }

  @type parse_result :: %{
          purchase_orders: [purchase_order_attrs],
          warnings: [String.t()]
        }

  @callback parse_purchase_order(Path.t()) :: {:ok, parse_result} | {:error, String.t()}

  @spec parse_purchase_order(Path.t()) :: {:ok, parse_result} | {:error, String.t()}
  def parse_purchase_order(path) do
    adapter().parse_purchase_order(path)
  end

  def adapter do
    Application.get_env(:boon, :pdf_intake_parser, Boon.PDF.HostParser)
  end
end
