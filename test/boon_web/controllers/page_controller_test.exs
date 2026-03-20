defmodule BoonWeb.PageControllerTest do
  use BoonWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    response = html_response(conn, 200)

    assert response =~ "Powdercoating Operations"
    assert response =~ "Work packages, purchase orders, and print — one flow."
    assert response =~ "Reviewed in intake and ready for print"
  end
end
