defmodule Boon.Accounts.User do
  use Ash.Resource,
    domain: Boon.Accounts,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshAuthentication]

  postgres do
    table("users")
    repo(Boon.Repo)
  end

  actions do
    defaults([:read])

    read :get_by_subject do
      description("Get a user by the subject claim in an authentication token")
      argument(:subject, :string, allow_nil?: false)
      get?(true)
      prepare(AshAuthentication.Preparations.FilterBySubject)
    end
  end

  authentication do
    tokens do
      enabled?(true)
      token_resource(Boon.Accounts.Token)
      require_token_presence_for_authentication?(true)

      signing_secret(fn _, _ ->
        Application.fetch_env!(:boon, BoonWeb.Endpoint)[:secret_key_base]
      end)
    end

    strategies do
      password :password do
        identity_field(:username)
        hashed_password_field(:hashed_password)
      end
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :username, :string do
      allow_nil?(false)
      public?(true)
      constraints(trim?: true, min_length: 1)
    end

    attribute :hashed_password, :string do
      allow_nil?(false)
      public?(false)
      sensitive?(true)
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  identities do
    identity(:unique_username, [:username])
  end
end
