defmodule Boon.Printing.PalletTagTransport do
  @moduledoc """
  Prints pallet-tag PDFs through SumatraPDF and a Windows printer queue.
  """

  @callback print(String.t(), String.t(), keyword) :: :ok | {:error, String.t()}

  @spec print(String.t(), String.t(), keyword) :: :ok | {:error, String.t()}
  def print(printer_name, pdf_path, opts \\ []) do
    sumatra_path = Keyword.get(opts, :sumatra_path) || configured_sumatra_path()

    cond do
      is_nil(sumatra_path) or sumatra_path == "" ->
        {:error, "SumatraPDF is not configured. Set :boon, :printing, :sumatra_path."}

      not File.exists?(sumatra_path) ->
        {:error, "SumatraPDF was not found at #{sumatra_path}."}

      not File.exists?(pdf_path) ->
        {:error, "The pallet-tag PDF payload does not exist at #{pdf_path}."}

      true ->
        args = ["-silent", "-print-to", printer_name, pdf_path]

        case System.cmd(sumatra_path, args, stderr_to_stdout: true) do
          {_, 0} ->
            :ok

          {output, exit_code} ->
            {:error, format_command_failure(output, exit_code, printer_name)}
        end
    end
  end

  defp configured_sumatra_path do
    :boon
    |> Application.get_env(:printing, [])
    |> Keyword.get(:sumatra_path)
  end

  defp format_command_failure(output, exit_code, printer_name) do
    normalized_output =
      output
      |> to_string()
      |> String.trim()

    base =
      "Sumatra pallet-tag print failed for printer #{printer_name} with exit code #{exit_code}."

    case normalized_output do
      "" -> base
      text -> base <> " " <> text
    end
  end
end
