defmodule Boon.PDF.HostParser do
  @moduledoc """
  Host-backed PDF parser that prefers embedded PDF text and falls back to OCR.

  The current implementation is intentionally small: it delegates layout parsing to
  `Boon.PDF.CamTranTextParser` and shells out to host utilities when present.
  """

  @behaviour Boon.PDF.IntakeParser

  alias Boon.PDF.CamTranTextParser

  @impl true
  def parse_purchase_order(path) do
    with :ok <- validate_file(path),
         {:ok, text} <- extract_embedded_text(path),
         {:ok, parsed} <- CamTranTextParser.parse(text) do
      {:ok, parsed}
    else
      {:error, :pdftotext_unavailable} ->
        parse_with_ocr(path)

      {:error, parser_error} ->
        case parse_with_ocr(path) do
          {:ok, parsed} -> {:ok, parsed}
          {:error, _ocr_error} -> {:error, parser_error}
        end
    end
  end

  defp validate_file(path) do
    if File.exists?(path) do
      :ok
    else
      {:error, "The uploaded PDF could not be read from temporary storage."}
    end
  end

  defp extract_embedded_text(path) do
    case resolve_executable("pdftotext", "Poppler `pdftotext`") do
      nil ->
        {:error, :pdftotext_unavailable}

      executable ->
        temp_base = temp_base("cam-tran-text")
        output_path = temp_base <> ".txt"

        try do
          case System.cmd(executable, ["-layout", "-f", "1", "-l", "1", path, output_path],
                 stderr_to_stdout: true
               ) do
            {_output, 0} -> File.read(output_path)
            {output, _status} -> {:error, normalize_command_error(output)}
          end
        after
          File.rm(output_path)
        end
    end
  end

  defp parse_with_ocr(path) do
    with {:ok, pdftoppm} <- fetch_executable("pdftoppm", "Poppler `pdftoppm`"),
         {:ok, tesseract} <- fetch_executable("tesseract", "Tesseract OCR"),
         {:ok, image_path} <- rasterize_first_page(pdftoppm, path),
         {:ok, text} <- ocr_image(tesseract, image_path) do
      CamTranTextParser.parse(text)
    end
  end

  defp fetch_executable(name, label) do
    case resolve_executable(name, label) do
      nil -> {:error, missing_executable_message(name, label)}
      executable -> {:ok, executable}
    end
  end

  defp resolve_executable(name, _label) do
    configured_executable(name) ||
      System.find_executable(name) ||
      Enum.find(common_windows_executable_paths(name), &File.exists?/1)
  end

  defp configured_executable(name) do
    tool_paths = Application.get_env(:boon, :pdf_tool_paths, %{})

    key =
      try do
        String.to_existing_atom(name)
      rescue
        ArgumentError -> nil
      end

    path =
      case key do
        nil -> Map.get(tool_paths, name)
        atom_key -> Map.get(tool_paths, atom_key, Map.get(tool_paths, name))
      end

    validate_configured_path(path)
  end

  defp common_windows_executable_paths(name) do
    program_files = System.get_env("ProgramFiles") || "C:/Program Files"
    local_app_data = System.get_env("LOCALAPPDATA") || ""

    case name do
      "tesseract" ->
        [
          Path.join(program_files, "Tesseract-OCR/tesseract.exe"),
          Path.join("C:/ProgramData/chocolatey/lib/tesseract/tools", "tesseract.exe")
        ]

      executable_name ->
        [
          Path.join(program_files, "poppler/bin/#{executable_name}.exe"),
          Path.join(program_files, "poppler/Library/bin/#{executable_name}.exe"),
          Path.join("C:/tools/poppler/bin", "#{executable_name}.exe"),
          Path.join("C:/tools/poppler/Library/bin", "#{executable_name}.exe"),
          Path.join(local_app_data, "Microsoft/WinGet/Packages/Poppler/#{executable_name}.exe")
        ]
    end
  end

  defp missing_executable_message(name, label) do
    config_hint =
      "You can also configure an explicit path under :boon, :pdf_tool_paths, for example #{name}: \"C:/path/to/#{name}.exe\"."

    case name do
      "pdftoppm" ->
        "PDF import requires #{label} to be installed on the app host. #{config_hint}"

      "pdftotext" ->
        "PDF import requires #{label} to be installed on the app host. #{config_hint}"

      _ ->
        "PDF import requires #{label} to be installed on the app host. #{config_hint}"
    end
  end

  defp validate_configured_path(path) when is_binary(path) and path != "" do
    if File.exists?(path), do: path, else: nil
  end

  defp validate_configured_path(_path), do: nil

  defp rasterize_first_page(pdftoppm, path) do
    temp_base = temp_base("cam-tran-page")
    image_path = temp_base <> "-1.png"

    case System.cmd(pdftoppm, ["-png", "-f", "1", "-l", "1", path, temp_base],
           stderr_to_stdout: true
         ) do
      {_output, 0} ->
        if File.exists?(image_path) do
          {:ok, image_path}
        else
          {:error, "PDF rasterization completed without producing an image file."}
        end

      {output, _status} ->
        {:error, normalize_command_error(output)}
    end
  end

  defp ocr_image(tesseract, image_path) do
    try do
      case System.cmd(tesseract, [image_path, "stdout", "--psm", "11"], stderr_to_stdout: true) do
        {output, 0} -> {:ok, output}
        {output, _status} -> {:error, normalize_command_error(output)}
      end
    after
      File.rm(image_path)
    end
  end

  defp temp_base(prefix) do
    Path.join(System.tmp_dir!(), "#{prefix}-#{System.unique_integer([:positive])}")
  end

  defp normalize_command_error(output) do
    output
    |> String.trim()
    |> case do
      "" -> "The host PDF extraction command failed."
      message -> message
    end
  end
end
