defmodule Boon.Accounts do
  use Ash.Domain

  resources do
    resource(Boon.Accounts.User)
    resource(Boon.Accounts.Token)
  end
end
