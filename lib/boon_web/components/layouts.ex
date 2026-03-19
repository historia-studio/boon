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
    <div class="min-h-screen bg-stone-950 text-stone-100">
      <header class="border-b border-white/10 bg-stone-950/90 backdrop-blur">
        <div class="mx-auto flex max-w-7xl items-center justify-between gap-6 px-4 py-4 sm:px-6 lg:px-8">
          <div>
            <.link navigate={~p"/"} class="flex items-center gap-3">
              <div class="flex h-10 w-10 items-center justify-center rounded-2xl border border-amber-400/40 bg-amber-300/10 text-amber-200">
                <.icon name="hero-cube-transparent" class="h-5 w-5" />
              </div>
              
              <div>
                <p class="text-xs uppercase tracking-[0.3em] text-stone-400">Boon</p>
                
                <p class="text-sm font-semibold text-stone-100">Powdercoating Operations</p>
              </div>
            </.link>
          </div>
          
          <nav class="flex flex-wrap items-center gap-2 text-sm">
            <.link
              navigate={~p"/"}
              class="rounded-full px-4 py-2 text-stone-300 transition hover:bg-white/5 hover:text-white"
            >
              Dashboard
            </.link>
            <.link
              navigate={~p"/intake"}
              class="rounded-full px-4 py-2 text-stone-300 transition hover:bg-white/5 hover:text-white"
            >
              Intake
            </.link>
            <.link
              navigate={~p"/work-packages"}
              class="rounded-full px-4 py-2 text-stone-300 transition hover:bg-white/5 hover:text-white"
            >
              Work Packages
            </.link>
            <.link
              navigate={~p"/review"}
              class="rounded-full px-4 py-2 text-stone-300 transition hover:bg-white/5 hover:text-white"
            >
              Review
            </.link>
            <.link
              navigate={~p"/ship"}
              class="rounded-full px-4 py-2 text-stone-300 transition hover:bg-white/5 hover:text-white"
            >
              Ship
            </.link>
          </nav>
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
