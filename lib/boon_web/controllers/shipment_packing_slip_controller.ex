defmodule BoonWeb.ShipmentPackingSlipController do
  use BoonWeb, :controller

  alias Boon.Operations
  alias Boon.Printing.Dispatcher

  def show(conn, %{"id" => id}) do
    shipment = Operations.get_shipment!(id)

    case Dispatcher.build_shipment_packing_slip_pdf(shipment) do
      {:ok, %{content: content, filename: filename}} ->
        conn
        |> put_resp_content_type("application/pdf")
        |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
        |> send_resp(200, content)

      {:error, %{error: error}} ->
        conn
        |> put_flash(:error, error)
        |> redirect(to: ~p"/shipments/#{id}")
    end
  end
end
