defmodule Boon.Shipping.PalletTagToken do
  @moduledoc """
  Deterministic signed token for pallet-tag shipping identity.
  """

  @delimiter "."

  @spec sign(String.t(), String.t(), pos_integer) :: String.t()
  def sign(work_package_id, purchase_order_id, pair_number) do
    payload = payload(work_package_id, purchase_order_id, pair_number)
    signature = sign_payload(payload)

    encode(payload) <> @delimiter <> encode(signature)
  end

  @spec verify(String.t()) ::
          {:ok,
           %{work_package_id: String.t(), purchase_order_id: String.t(), pair_number: integer}}
          | {:error, String.t()}
  def verify(token) when is_binary(token) do
    case String.split(token, @delimiter, parts: 2) do
      [encoded_payload, encoded_signature] ->
        with {:ok, payload} <- decode(encoded_payload),
             {:ok, signature} <- decode(encoded_signature),
             true <-
               secure_compare(signature, sign_payload(payload)) ||
                 {:error, "The pallet-tag token signature is invalid."},
             {:ok, parsed} <- parse_payload(payload) do
          {:ok, parsed}
        else
          {:error, _error} = error -> error
          false -> {:error, "The pallet-tag token signature is invalid."}
        end

      _other ->
        {:error, "The pallet-tag token format is invalid."}
    end
  end

  def verify(_token), do: {:error, "The pallet-tag token format is invalid."}

  defp payload(work_package_id, purchase_order_id, pair_number) do
    Enum.join([work_package_id, purchase_order_id, pair_number], ":")
  end

  defp parse_payload(payload) do
    case String.split(payload, ":", parts: 3) do
      [work_package_id, purchase_order_id, pair_number] ->
        case Integer.parse(pair_number) do
          {parsed_pair_number, ""} when parsed_pair_number > 0 ->
            {:ok,
             %{
               work_package_id: work_package_id,
               purchase_order_id: purchase_order_id,
               pair_number: parsed_pair_number
             }}

          _other ->
            {:error, "The pallet-tag token pair number is invalid."}
        end

      _other ->
        {:error, "The pallet-tag token payload is invalid."}
    end
  end

  defp sign_payload(payload) do
    :crypto.mac(:hmac, :sha256, endpoint_secret(), payload)
  end

  defp endpoint_secret do
    :boon
    |> Application.fetch_env!(BoonWeb.Endpoint)
    |> Keyword.fetch!(:secret_key_base)
  end

  defp encode(data), do: Base.url_encode64(data, padding: false)

  defp decode(data) do
    case Base.url_decode64(data, padding: false) do
      {:ok, decoded} -> {:ok, decoded}
      :error -> {:error, "The pallet-tag token contains invalid encoding."}
    end
  end

  defp secure_compare(left, right) when byte_size(left) == byte_size(right),
    do: Plug.Crypto.secure_compare(left, right)

  defp secure_compare(_left, _right), do: false
end
