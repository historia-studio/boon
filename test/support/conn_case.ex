defmodule BoonWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use BoonWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate
  import AshAuthentication.Phoenix.Plug, only: [store_in_session: 2]

  using do
    quote do
      # The default endpoint for testing
      @endpoint BoonWeb.Endpoint

      use BoonWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import BoonWeb.ConnCase
    end
  end

  setup tags do
    Boon.DataCase.setup_sandbox(tags)

    conn = Phoenix.ConnTest.build_conn()

    if Map.get(tags, :authenticate, true) do
      {:ok, register_and_log_in_user(%{conn: conn})}
    else
      {:ok, conn: conn, current_user: nil}
    end
  end

  def register_and_log_in_user(%{conn: conn} = context) do
    username = "test-#{System.unique_integer([:positive])}"
    password = "password123!"
    strategy = AshAuthentication.Info.strategy!(Boon.Accounts.User, :password)

    Boon.Accounts.ensure_user!(username, password)

    {:ok, authenticated_user} =
      AshAuthentication.Strategy.Password.Actions.sign_in(
        strategy,
        %{"username" => username, "password" => password},
        []
      )

    conn =
      conn
      |> Phoenix.ConnTest.init_test_session(%{})
      |> store_in_session(authenticated_user)
      |> Plug.Conn.assign(:current_user, authenticated_user)

    context
    |> Map.put(:conn, conn)
    |> Map.put(:current_user, authenticated_user)
  end
end
