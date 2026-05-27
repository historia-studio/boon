defmodule Boon.Repo.Migrations.AddAuthenticationTables do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:users, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :username, :text, null: false
      add :hashed_password, :text, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create_if_not_exists unique_index(:users, [:username])

    create_if_not_exists table(:tokens, primary_key: false) do
      add :jti, :text, primary_key: true
      add :subject, :text, null: false
      add :expires_at, :utc_datetime, null: false
      add :purpose, :text, null: false
      add :extra_data, :map

      timestamps(type: :utc_datetime_usec, inserted_at: :created_at, updated_at: :updated_at)
    end

    create_if_not_exists index(:tokens, [:subject])
    create_if_not_exists index(:tokens, [:expires_at])
  end
end
