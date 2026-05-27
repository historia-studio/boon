defmodule Boon.Repo.Migrations.NormalizeAuthenticationUserIdentity do
  use Ecto.Migration

  def up do
    execute("""
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = 'users'
      ) THEN
        IF EXISTS (
          SELECT 1
          FROM information_schema.columns
          WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'email'
        ) AND NOT EXISTS (
          SELECT 1
          FROM information_schema.columns
          WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'username'
        ) THEN
          ALTER TABLE users RENAME COLUMN email TO username;
        END IF;
      END IF;
    END
    $$;
    """)

    execute("DROP INDEX IF EXISTS users_email_index")

    create_if_not_exists unique_index(:users, [:username])
  end

  def down do
    drop_if_exists unique_index(:users, [:username])

    execute("""
    DO $$
    BEGIN
      IF EXISTS (
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = 'public' AND table_name = 'users'
      ) THEN
        IF EXISTS (
          SELECT 1
          FROM information_schema.columns
          WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'username'
        ) AND NOT EXISTS (
          SELECT 1
          FROM information_schema.columns
          WHERE table_schema = 'public' AND table_name = 'users' AND column_name = 'email'
        ) THEN
          ALTER TABLE users RENAME COLUMN username TO email;
        END IF;
      END IF;
    END
    $$;
    """)

    create_if_not_exists unique_index(:users, [:email])
  end
end