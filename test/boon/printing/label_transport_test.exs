defmodule Boon.Printing.LabelTransportTest do
  use ExUnit.Case, async: true

  alias Boon.Printing.LabelTransport

  test "uses Windows raw queue mode when configured" do
    runner = fn command, args, opts ->
      send(self(), {:command, command, args, opts})
      {"RAW label bytes sent: 42", 0}
    end

    assert :ok =
             LabelTransport.print(
               "Label Maker",
               "^XA^FDTEST^FS^XZ",
               endpoint: %{mode: :windows_raw_queue},
               powershell_path: "powershell.exe",
               command_runner: runner
             )

    assert_receive {:command, "powershell.exe", args, opts}
    assert "-EncodedCommand" in args
    assert opts[:stderr_to_stdout] == true
  end

  test "returns a useful error when no transport is configured" do
    assert {:error, message} = LabelTransport.print("Label Maker", "^XA^XZ", endpoint: %{})
    assert message =~ "No label transport is configured"
  end
end
