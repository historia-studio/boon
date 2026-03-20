defmodule Boon.Printing.LabelTransport do
  @moduledoc """
  Sends rendered label ZPL to a label printer over raw TCP.
  """

  @callback print(String.t(), String.t(), keyword) :: :ok | {:error, String.t()}

  @default_port 9100
  @default_timeout 5_000

  @spec print(String.t(), String.t(), keyword) :: :ok | {:error, String.t()}
  def print(printer_name, zpl, opts \\ []) when is_binary(printer_name) and is_binary(zpl) do
    endpoint = Keyword.get(opts, :endpoint) || configured_endpoint(printer_name)
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    case endpoint do
      %{host: host} = endpoint when is_binary(host) and host != "" ->
        port = Map.get(endpoint, :port, @default_port)
        connect_and_send(host, port, zpl, timeout)

      _ ->
        {:error,
         "No TCP endpoint is configured for label printer #{printer_name}. Configure :boon, :printing, :label_printer_endpoints first."}
    end
  end

  defp configured_endpoint(printer_name) do
    :boon
    |> Application.get_env(:printing, [])
    |> Keyword.get(:label_printer_endpoints, %{})
    |> Map.get(printer_name)
  end

  defp connect_and_send(host, port, zpl, timeout) do
    with {:ok, socket} <-
           :gen_tcp.connect(String.to_charlist(host), port, [:binary, active: false], timeout),
         :ok <- :gen_tcp.send(socket, zpl) do
      :gen_tcp.close(socket)
      :ok
    else
      {:error, reason} -> {:error, "TCP label print failed: #{format_reason(reason)}"}
    end
  end

  defp format_reason(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp format_reason(reason), do: to_string(reason)
end
