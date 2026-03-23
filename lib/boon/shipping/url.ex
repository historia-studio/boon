defmodule Boon.Shipping.URL do
  @moduledoc """
  Builds shipping URLs for pallet-tag QR codes and deep links.
  """

  alias Boon.Shipping.PalletTagToken

  @spec pallet_tag_url(String.t(), String.t(), pos_integer, String.t()) :: String.t()
  def pallet_tag_url(work_package_id, purchase_order_id, pair_number, pallet_type) do
    token = PalletTagToken.sign(work_package_id, purchase_order_id, pair_number, pallet_type)
    config = Application.get_env(:boon, :shipping, [])
    scheme = Keyword.get(config, :scheme, "http")
    host = Keyword.get(config, :host, "BOON")
    port = Keyword.get(config, :port, 4000)

    "#{scheme}://#{host}:#{port}/ship?tag=#{URI.encode_www_form(token)}"
  end
end
