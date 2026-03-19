defmodule Boon.PDF.UploadImporterTest do
  use ExUnit.Case, async: true

  alias Boon.PDF.UploadImporter

  setup do
    original_parser = Application.get_env(:boon, :pdf_intake_parser)
    Application.put_env(:boon, :pdf_intake_parser, Boon.PDF.ParserStub)

    on_exit(fn ->
      Application.put_env(:boon, :pdf_intake_parser, original_parser)
    end)

    :ok
  end

  test "imports a single uploaded pdf" do
    pdf_path = Path.expand("../../../reference/wp10/63129.pdf", __DIR__)

    result = UploadImporter.import_upload(pdf_path, "63129.pdf")

    assert result.errors == []
    assert result.warnings == ["Imported with the test parser stub."]
    assert length(result.purchase_orders) == 1
    assert hd(result.purchase_orders).po_number == "63129"
  end

  test "imports all pdfs from a zip upload" do
    pdf_path = Path.expand("../../../reference/wp10/63129.pdf", __DIR__)
    pdf_content = File.read!(pdf_path)
    zip_path = temp_path("batch.zip")

    try do
      {:ok, _zip_file} =
        :zip.create(String.to_charlist(zip_path), [
          {~c"63129-a.pdf", pdf_content},
          {~c"63129-b.pdf", pdf_content}
        ])

      result = UploadImporter.import_upload(zip_path, "batch.zip")

      assert result.errors == []

      assert result.warnings == [
               "Imported with the test parser stub.",
               "Imported with the test parser stub."
             ]

      assert length(result.purchase_orders) == 2
      assert Enum.map(result.purchase_orders, & &1.po_number) == ["63129", "63129"]
    after
      File.rm(zip_path)
    end
  end

  defp temp_path(filename) do
    Path.join(System.tmp_dir!(), "boon-#{System.unique_integer([:positive])}-#{filename}")
  end
end
