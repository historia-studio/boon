defmodule Boon.Repo do
  use Ecto.Repo,
    otp_app: :boon,
    adapter: Ecto.Adapters.Postgres
end
