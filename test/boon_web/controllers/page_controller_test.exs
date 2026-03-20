defmodule BoonWeb.PageControllerTest do
  use BoonWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    response = html_response(conn, 200)

    assert response =~ "Powdercoating Operations"
    assert response =~ "Track work packages, purchase orders, and line items"
    assert response =~ "Manual intake is available now"
  end
end
