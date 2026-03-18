defmodule BoonWeb.PageControllerTest do
  use BoonWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    response = html_response(conn, 200)

    assert response =~ "Powdercoating Operations"

    assert response =~
             "Build the operator workspace before intake, printing, and shipping logic lands."
  end
end
