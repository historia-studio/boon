defmodule Boon.Accounts.Token do
  use Ash.Resource,
    domain: Boon.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication.TokenResource]

  postgres do
    table("tokens")
    repo(Boon.Repo)
  end
end
