defmodule Boon.Accounts.User do
  use Ash.Resource,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication],
    domain: Boon.Accounts

  postgres do
    table("users")
    repo(Boon.Repo)
  end

  actions do
    defaults([:read])

    create :create do
      accept([:username, :hashed_password])
      upsert?(true)
      upsert_identity(:unique_username)
    end

    read :get_by_subject do
      description("Get a user by the subject claim in a JWT")
      argument(:subject, :string, allow_nil?: false)
      get?(true)
      prepare(AshAuthentication.Preparations.FilterBySubject)
    end
  end

  authentication do
    session_identifier(:jti)

    tokens do
      enabled?(true)
      token_resource(Boon.Accounts.Token)

      signing_secret(fn _, _ ->
        {:ok, Application.fetch_env!(:boon, :token_signing_secret)}
      end)
    end

    strategies do
      password :password do
        identity_field(:username)
        hashed_password_field(:hashed_password)
        registration_enabled?(false)
        sign_in_tokens_enabled?(true)
      end
    end
  end

  identities do
    identity(:unique_username, [:username])
  end

  attributes do
    uuid_primary_key(:id)

    attribute :username, :string do
      allow_nil?(false)
      public?(true)
      constraints(trim?: true, min_length: 3)
    end

    attribute :hashed_password, :string do
      allow_nil?(false)
      sensitive?(true)
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end
end
