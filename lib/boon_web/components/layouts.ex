defmodule BoonWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use BoonWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <div class="min-h-screen text-stone-100">
      <header class="sticky top-0 z-30 border-b border-white/10 bg-[#120b0bcc] backdrop-blur-xl">
        <div class="mx-auto flex max-w-7xl flex-col gap-5 px-4 py-4 sm:px-6 lg:flex-row lg:items-center lg:justify-between lg:px-8">
          <div class="flex items-center justify-between gap-4">
            <.link navigate={~p"/"} class="flex items-center gap-4">
              <div class="flex h-12 w-12 items-center justify-center rounded-[1.25rem] border border-red-300/20 bg-red-400/10 text-red-200 shadow-[0_12px_30px_rgba(239,68,68,0.18)]">
                <.icon name="hero-cube-transparent" class="h-6 w-6" />
              </div>

              <div class="space-y-2">
                <BoonWeb.Components.Badge.badge
                  color="warning"
                  variant="bordered"
                  rounded="full"
                  class="w-fit text-[0.65rem] font-medium uppercase tracking-[0.24em]"
                >
                  Operator Workflow
                </BoonWeb.Components.Badge.badge>

                <div>
                  <p class="text-xs uppercase tracking-[0.28em] text-stone-500">Boon</p>
                  <p class="text-sm font-semibold text-stone-100">Powdercoating Operations</p>
                </div>
              </div>
            </.link>

            <BoonWeb.Components.Button.button_link
              navigate={~p"/intake"}
              variant="shadow"
              color="danger"
              icon="hero-plus"
              size="medium"
              class="lg:hidden"
            >
              New Intake
            </BoonWeb.Components.Button.button_link>
          </div>

          <div class="flex flex-col gap-4 lg:flex-row lg:items-center">
            <nav class="flex flex-wrap items-center gap-2 text-sm">
              <.link navigate={~p"/"} class="app-nav-link rounded-full px-4 py-2">Dashboard</.link>
              <.link navigate={~p"/intake"} class="app-nav-link rounded-full px-4 py-2">Intake</.link>
              <.link navigate={~p"/work-packages"} class="app-nav-link rounded-full px-4 py-2">
                Work Packages
              </.link>
              <.link navigate={~p"/shipments"} class="app-nav-link rounded-full px-4 py-2">
                Shipments
              </.link>
              <.link navigate={~p"/ship"} class="app-nav-link rounded-full px-4 py-2">Ship</.link>
            </nav>

            <BoonWeb.Components.Button.button_link
              navigate={~p"/intake"}
              variant="shadow"
              color="danger"
              icon="hero-plus"
              size="medium"
              class="hidden lg:inline-flex"
            >
              New Intake
            </BoonWeb.Components.Button.button_link>
          </div>
        </div>
      </header>

      <main class="mx-auto max-w-7xl px-4 py-8 sm:px-6 lg:px-8">{render_slot(@inner_block)}</main>
      <.flash_group flash={@flash} />
    </div>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} /> <.flash kind={:error} flash={@flash} />
      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end
end
