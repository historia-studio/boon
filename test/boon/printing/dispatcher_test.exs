defmodule Boon.Printing.DispatcherTest do
  use Boon.DataCase, async: false

  alias Boon.Operations
  alias Boon.Operations.PrintJob
  alias Boon.Printing.Dispatcher

  defmodule LabelTransportStub do
    @behaviour Boon.Printing.LabelTransport

    @impl true
    def print(printer_name, zpl, opts) do
      if notify = Keyword.get(opts, :notify) do
        send(notify, {:label_printed, printer_name, zpl})
      end

      Keyword.get(opts, :result, :ok)
    end
  end

  defmodule PalletTagTransportStub do
    @behaviour Boon.Printing.PalletTagTransport

    @impl true
    def print(printer_name, pdf_path, opts) do
      if notify = Keyword.get(opts, :notify) do
        pdf_header = pdf_path |> File.read!() |> binary_part(0, 8)
        send(notify, {:pallet_tag_printed, printer_name, pdf_path, pdf_header})
      end

      Keyword.get(opts, :result, :ok)
    end
  end

  describe "dispatch_work_package/2" do
    test "records completed label and pallet-tag jobs when transports succeed" do
      work_package = work_package_fixture("chilliwack")
      temp_dir = Path.join(System.tmp_dir!(), "boon-printing-tests")

      assert {:ok, summary} =
               Dispatcher.dispatch_work_package(
                 work_package,
                 temp_dir: temp_dir,
                 label_transport: LabelTransportStub,
                 label_transport_opts: [notify: self()],
                 pallet_tag_transport: PalletTagTransportStub,
                 pallet_tag_transport_opts: [notify: self()]
               )

      assert_receive {:label_printed, "Label Maker", zpl}
      assert zpl =~ "^FD86-SA-T100^FS"
      assert zpl =~ "^FD86-SA-L100^FS"

      assert_receive {:pallet_tag_printed, "Chilliwack", pdf_path, "%PDF-1.4"}
      assert File.exists?(pdf_path)

      assert summary.errors == []
      assert summary.label_job.status == :completed
      assert Enum.map(summary.pallet_tag_jobs, & &1.status) == [:completed]

      jobs = PrintJob |> Ash.read!() |> Enum.sort_by(&{&1.document_type, &1.target_printer})

      assert Enum.map(jobs, & &1.status) == ["completed", "completed"]
      assert Enum.map(jobs, & &1.document_type) == ["labels", "pallet_tags"]
    end

    test "records failed pallet-tag jobs when the printer command fails" do
      work_package = work_package_fixture("spruce_grove")

      assert {:ok, summary} =
               Dispatcher.dispatch_work_package(
                 work_package,
                 temp_dir: Path.join(System.tmp_dir!(), "boon-printing-tests"),
                 label_transport: LabelTransportStub,
                 pallet_tag_transport: PalletTagTransportStub,
                 pallet_tag_transport_opts: [result: {:error, "Printer offline"}]
               )

      assert summary.label_job.status == :completed

      assert [%{status: :failed, error: error}] = summary.pallet_tag_jobs
      assert error == "Printer offline"
      assert summary.errors == ["Printer offline"]

      failed_job =
        PrintJob
        |> Ash.read!()
        |> Enum.find(&(&1.document_type == "pallet_tags"))

      assert failed_job.status == "failed"
      assert failed_job.target_printer == "Spruce Grove"
      assert failed_job.error_details == "Printer offline"
    end
  end

  defp work_package_fixture(ship_to) do
    {:ok, work_package} =
      Operations.create_work_package_entry(%{
        number: "WP-#{System.unique_integer([:positive])}",
        purchase_orders: [
          %{
            po_number: "PO-#{System.unique_integer([:positive])}",
            order_date: ~D[2026-03-20],
            revision_date: ~D[2026-03-21],
            reference: "TRANSFORMER, ANSI/IEEE GREEN, PRIORITY",
            ship_to: ship_to,
            lines: [
              %{line: 1, item_number: "86-SA-T100", quantity: 1, ship_date: ~D[2026-04-10]},
              %{line: 2, item_number: "86-SA-C100", quantity: 1, ship_date: ~D[2026-04-10]},
              %{line: 3, item_number: "86-SA-L100", quantity: 1, ship_date: ~D[2026-04-10]}
            ]
          }
        ]
      })

    work_package
  end
end
