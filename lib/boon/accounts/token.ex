defmodule Boon.Accounts.Token do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication.TokenResource],
    domain: Boon.Accounts

  postgres do
    table("tokens")
    repo(Boon.Repo)
  end
end
