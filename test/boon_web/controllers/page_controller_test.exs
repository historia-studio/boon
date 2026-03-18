defmodule BoonWeb.PageControllerTest do
  use BoonWeb.ConnCase

  test "GET / redirects unauthenticated users to sign in", %{conn: conn} do
    conn = get(conn, ~p"/")

    assert redirected_to(conn, 302) == ~p"/sign-in"
  end

  test "GET /sign-in renders the password sign-in screen", %{conn: conn} do
    conn = get(conn, ~p"/sign-in")
    response = html_response(conn, 200)

    assert response =~ "Sign in"
    assert response =~ "Register"
  end
end
