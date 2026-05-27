defmodule Boon.Accounts do
  use Ash.Domain

  alias Boon.Accounts.User

  resources do
    resource(Boon.Accounts.User)
    resource(Boon.Accounts.Token)
  end

  def ensure_user!(username, password) when is_binary(username) and is_binary(password) do
    {:ok, hashed_password} = AshAuthentication.BcryptProvider.hash(password)

    User
    |> Ash.Changeset.for_create(:create, %{username: username, hashed_password: hashed_password})
    |> Ash.create!()
  end
end
