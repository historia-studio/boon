defmodule Boon.Shipping.PalletTagTokenTest do
  use ExUnit.Case, async: true

  alias Boon.Shipping.PalletTagToken

  test "signs and verifies a deterministic pallet-tag token" do
    token = PalletTagToken.sign("wp-1", "po-1", 3, "tank")

    assert token == PalletTagToken.sign("wp-1", "po-1", 3, "tank")

    assert {:ok, token_data} = PalletTagToken.verify(token)
    assert token_data.work_package_id == "wp-1"
    assert token_data.purchase_order_id == "po-1"
    assert token_data.pair_number == 3
    assert token_data.pallet_type == "tank"
  end

  test "rejects a tampered pallet-tag token" do
    token = PalletTagToken.sign("wp-1", "po-1", 3, "tank")
    tampered = token <> "x"

    assert {:error, _message} = PalletTagToken.verify(tampered)
  end
end
