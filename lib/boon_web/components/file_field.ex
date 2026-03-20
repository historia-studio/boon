defmodule BoonWeb.Components.FileField do
  @moduledoc """
  Styled file upload field for LiveView uploads.

  The component follows the Chelekom form-field shape while wrapping
  `live_file_input/1` so upload controls stay consistent with the rest of the UI.

  Documentation inspiration: https://mishka.tools/chelekom/docs/forms/file-field
  """

  use Phoenix.Component

  import BoonWeb.Components.Icon, only: [icon: 1]
  import BoonWeb.Components.InputField, only: [label: 1]

  @doc type: :component
  attr :upload, :map, required: true, doc: "LiveView upload assign"
  attr :label, :string, required: true, doc: "Field label"
  attr :selected_title, :string, default: "Selected Files", doc: "Entries section title"
  attr :empty_message, :string, default: "No files selected.", doc: "Empty state copy"
  attr :class, :string, default: nil, doc: "Wrapper classes"
  attr :input_class, :string, default: nil, doc: "Input classes"
  attr :entries_class, :string, default: nil, doc: "Selected entries classes"

  attr :rest, :global, doc: "Global attributes passed to the wrapper"

  def file(assigns) do
    ~H"""
    <div class={["space-y-3", @class]} {@rest}>
      <.label for={@upload.ref}>{@label}</.label>

      <.live_file_input
        upload={@upload}
        class={[
          "block w-full rounded-[1rem] border border-white/10 bg-[#140d0d] px-4 py-3 text-sm text-stone-200 shadow-[inset_0_1px_0_rgba(255,255,255,0.03)] outline-none transition file:mr-4 file:rounded-full file:border-0 file:bg-red-400/15 file:px-3 file:py-2 file:text-sm file:font-semibold file:text-red-100 hover:border-amber-300/35 focus:border-amber-300/60 focus:ring-2 focus:ring-amber-300/15",
          @input_class
        ]}
      />
      <div class={[
        "rounded-[1rem] border border-white/10 bg-black/20 px-4 py-3",
        @entries_class
      ]}>
        <p class="text-xs font-semibold uppercase tracking-[0.2em] text-stone-400">
          {@selected_title}
        </p>

        <p :if={@upload.entries == []} class="mt-2 text-sm text-stone-500">{@empty_message}</p>

        <ul :if={@upload.entries != []} class="mt-2 space-y-2">
          <li
            :for={entry <- @upload.entries}
            class="flex items-center justify-between gap-3 rounded-[0.9rem] border border-white/6 bg-white/[0.03] px-3 py-2 text-sm text-stone-200"
          >
            <span class="flex min-w-0 items-center gap-2">
              <.icon name="hero-document" class="h-4 w-4 shrink-0 text-amber-300" />
              <span class="truncate">{entry.client_name}</span>
            </span>
             <span class="shrink-0 text-xs text-stone-500">{entry.progress}%</span>
          </li>
        </ul>
      </div>
    </div>
    """
  end
end
