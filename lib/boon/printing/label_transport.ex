defmodule Boon.Printing.LabelTransport do
  @moduledoc """
  Sends rendered label ZPL either over raw TCP or through the local Windows
  printer queue when the label printer is USB-attached.
  """

  @callback print(String.t(), String.t(), keyword) :: :ok | {:error, String.t()}

  @default_port 9100
  @default_timeout 5_000

  @spec print(String.t(), String.t(), keyword) :: :ok | {:error, String.t()}
  def print(printer_name, zpl, opts \\ []) when is_binary(printer_name) and is_binary(zpl) do
    endpoint = Keyword.get(opts, :endpoint) || configured_endpoint(printer_name)
    timeout = Keyword.get(opts, :timeout, @default_timeout)

    case endpoint do
      %{mode: :windows_raw_queue} ->
        send_via_windows_queue(printer_name, zpl, opts)

      %{host: host} = endpoint when is_binary(host) and host != "" ->
        port = Map.get(endpoint, :port, @default_port)
        connect_and_send(host, port, zpl, timeout)

      _ ->
        {:error,
         "No label transport is configured for printer #{printer_name}. Configure :boon, :printing, :label_printer_endpoints with either a TCP host or mode: :windows_raw_queue."}
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

  defp send_via_windows_queue(printer_name, zpl, opts) do
    command_runner = Keyword.get(opts, :command_runner, &default_command_runner/3)

    powershell =
      Keyword.get(
        opts,
        :powershell_path,
        System.find_executable("powershell.exe") || System.find_executable("powershell")
      )

    cond do
      is_nil(powershell) ->
        {:error, "PowerShell was not found, so raw Windows label printing is unavailable."}

      true ->
        encoded_command = windows_raw_queue_command(printer_name, zpl)

        case command_runner.(
               powershell,
               ["-NoProfile", "-NonInteractive", "-EncodedCommand", encoded_command],
               stderr_to_stdout: true
             ) do
          {_, 0} ->
            :ok

          {output, exit_code} ->
            {:error, format_windows_queue_failure(output, exit_code, printer_name)}
        end
    end
  end

  defp windows_raw_queue_command(printer_name, zpl) do
    printer_literal = String.replace(printer_name, "'", "''")
    payload_base64 = Base.encode64(zpl)

    script = """
    $printerName = '#{printer_literal}'
    $payload = [System.Convert]::FromBase64String('#{payload_base64}')
    Add-Type -TypeDefinition @'
    using System;
    using System.Runtime.InteropServices;
    public static class RawPrinterHelper {
      [DllImport("winspool.drv", EntryPoint="OpenPrinterW", SetLastError=true, CharSet=CharSet.Unicode)]
      public static extern bool OpenPrinter(string pPrinterName, out IntPtr phPrinter, IntPtr pDefault);
      [DllImport("winspool.drv", SetLastError=true)]
      public static extern bool ClosePrinter(IntPtr hPrinter);
      [DllImport("winspool.drv", EntryPoint="StartDocPrinterW", SetLastError=true, CharSet=CharSet.Unicode)]
      public static extern bool StartDocPrinter(IntPtr hPrinter, int level, ref DOC_INFO_1 docInfo);
      [DllImport("winspool.drv", SetLastError=true)]
      public static extern bool EndDocPrinter(IntPtr hPrinter);
      [DllImport("winspool.drv", SetLastError=true)]
      public static extern bool StartPagePrinter(IntPtr hPrinter);
      [DllImport("winspool.drv", SetLastError=true)]
      public static extern bool EndPagePrinter(IntPtr hPrinter);
      [DllImport("winspool.drv", SetLastError=true)]
      public static extern bool WritePrinter(IntPtr hPrinter, IntPtr pBytes, int dwCount, out int dwWritten);
      [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
      public struct DOC_INFO_1 {
        [MarshalAs(UnmanagedType.LPWStr)] public string pDocName;
        [MarshalAs(UnmanagedType.LPWStr)] public string pOutputFile;
        [MarshalAs(UnmanagedType.LPWStr)] public string pDataType;
      }
    }
    '@
    $handle = [IntPtr]::Zero
    if (-not [RawPrinterHelper]::OpenPrinter($printerName, [ref]$handle, [IntPtr]::Zero)) {
      throw "OpenPrinter failed: $([Runtime.InteropServices.Marshal]::GetLastWin32Error())"
    }
    try {
      $doc = New-Object RawPrinterHelper+DOC_INFO_1
      $doc.pDocName = 'Boon Label Print'
      $doc.pDataType = 'RAW'
      if (-not [RawPrinterHelper]::StartDocPrinter($handle, 1, [ref]$doc)) {
        throw "StartDocPrinter failed: $([Runtime.InteropServices.Marshal]::GetLastWin32Error())"
      }
      try {
        if (-not [RawPrinterHelper]::StartPagePrinter($handle)) {
          throw "StartPagePrinter failed: $([Runtime.InteropServices.Marshal]::GetLastWin32Error())"
        }
        $ptr = [Runtime.InteropServices.Marshal]::AllocCoTaskMem($payload.Length)
        try {
          [Runtime.InteropServices.Marshal]::Copy($payload, 0, $ptr, $payload.Length)
          $written = 0
          if (-not [RawPrinterHelper]::WritePrinter($handle, $ptr, $payload.Length, [ref]$written)) {
            throw "WritePrinter failed: $([Runtime.InteropServices.Marshal]::GetLastWin32Error())"
          }
          Write-Output "RAW label bytes sent: $written"
        }
        finally {
          [Runtime.InteropServices.Marshal]::FreeCoTaskMem($ptr)
        }
        if (-not [RawPrinterHelper]::EndPagePrinter($handle)) {
          throw "EndPagePrinter failed: $([Runtime.InteropServices.Marshal]::GetLastWin32Error())"
        }
      }
      finally {
        if (-not [RawPrinterHelper]::EndDocPrinter($handle)) {
          throw "EndDocPrinter failed: $([Runtime.InteropServices.Marshal]::GetLastWin32Error())"
        }
      }
    }
    finally {
      [RawPrinterHelper]::ClosePrinter($handle) | Out-Null
    }
    """

    script
    |> :unicode.characters_to_binary(:utf8, {:utf16, :little})
    |> Base.encode64()
  end

  defp format_windows_queue_failure(output, exit_code, printer_name) do
    message =
      output
      |> to_string()
      |> String.trim()

    base =
      "Windows raw label print failed for printer #{printer_name} with exit code #{exit_code}."

    case message do
      "" -> base
      text -> base <> " " <> text
    end
  end

  defp default_command_runner(command, args, opts), do: System.cmd(command, args, opts)

  defp format_reason(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp format_reason(reason), do: to_string(reason)
end
