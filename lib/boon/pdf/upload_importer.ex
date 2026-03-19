defmodule Boon.PDF.UploadImporter do
  @moduledoc """
  Expands uploaded PDF or ZIP files into aggregated purchase-order parse results.
  """

  alias Boon.PDF.IntakeParser

  @type import_result :: %{
          purchase_orders: [IntakeParser.purchase_order_attrs()],
          warnings: [String.t()],
          errors: [String.t()]
        }

  @spec import_upload(Path.t(), String.t()) :: import_result
  def import_upload(path, client_name) do
    case client_name |> Path.extname() |> String.downcase() do
      ".pdf" -> import_pdf(path, client_name)
      ".zip" -> import_zip(path, client_name)
      _other -> empty_result(["#{client_name}: unsupported upload type."])
    end
  end

  defp import_pdf(path, client_name) do
    case IntakeParser.parse_purchase_order(path) do
      {:ok, %{purchase_orders: purchase_orders, warnings: warnings}} ->
        %{purchase_orders: purchase_orders, warnings: warnings, errors: []}

      {:error, error} ->
        empty_result(["#{client_name}: #{error}"])
    end
  end

  defp import_zip(path, client_name) do
    temp_dir = Path.join(System.tmp_dir!(), "boon-upload-#{System.unique_integer([:positive])}")
    File.mkdir_p!(temp_dir)

    try do
      case :zip.extract(String.to_charlist(path), [:memory]) do
        {:ok, files} ->
          case extracted_pdf_entries(files) do
            [] ->
              empty_result(["#{client_name}: ZIP archive did not contain any PDF files."])

            pdf_entries ->
              Enum.reduce(pdf_entries, empty_result(), fn {entry_name, binary}, result ->
                pdf_path = write_zip_pdf(temp_dir, entry_name, binary)
                file_result = import_pdf(pdf_path, "#{client_name}/#{Path.basename(entry_name)}")

                %{
                  purchase_orders: result.purchase_orders ++ file_result.purchase_orders,
                  warnings: result.warnings ++ file_result.warnings,
                  errors: result.errors ++ file_result.errors
                }
              end)
          end

        {:error, reason} ->
          empty_result(["#{client_name}: could not extract ZIP archive (#{inspect(reason)})."])
      end
    after
      File.rm_rf(temp_dir)
    end
  end

  defp extracted_pdf_entries(files) do
    files
    |> Enum.reduce([], fn
      {name, binary}, entries when is_list(name) and is_binary(binary) ->
        entry_name = to_string(name)

        if String.downcase(Path.extname(entry_name)) == ".pdf" do
          [{entry_name, binary} | entries]
        else
          entries
        end

      _other, entries ->
        entries
    end)
    |> Enum.sort()
  end

  defp write_zip_pdf(temp_dir, entry_name, binary) do
    pdf_path =
      Path.join(
        temp_dir,
        "#{System.unique_integer([:positive])}-#{Path.basename(entry_name)}"
      )

    File.write!(pdf_path, binary)
    pdf_path
  end

  defp empty_result(errors \\ []) do
    %{purchase_orders: [], warnings: [], errors: errors}
  end
end
