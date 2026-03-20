defmodule Boon.Printing.ReferenceColor do
  @moduledoc """
  Extracts the printable color segment from a purchase-order reference.
  """

  alias Boon.Printing.PurchaseOrderReference

  @spec extract(String.t() | nil) :: String.t() | nil
  def extract(reference) when is_binary(reference) do
    PurchaseOrderReference.color(reference)
  end

  def extract(_reference), do: nil
end
