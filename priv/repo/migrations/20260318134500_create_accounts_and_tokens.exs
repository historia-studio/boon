defmodule Boon.Repo.Migrations.CreateAccountsAndTokens do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :username, :text, null: false
      add :hashed_password, :text, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:users, [:username])

    create table(:tokens, primary_key: false) do
      add :jti, :text, primary_key: true
      add :subject, :text, null: false
      add :expires_at, :utc_datetime_usec, null: false
      add :purpose, :text, null: false
      add :extra_data, :map
      add :created_at, :utc_datetime_usec, null: false
      add :updated_at, :utc_datetime_usec, null: false
    end

    create index(:tokens, [:subject])
    create index(:tokens, [:expires_at])
    create index(:tokens, [:purpose])
  end
end
