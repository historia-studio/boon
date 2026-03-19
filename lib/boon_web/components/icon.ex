defmodule BoonWeb.Components.Icon do
  use Phoenix.Component

  attr :name, :string, required: true
  attr :class, :any, default: nil
  attr :rest, :global

  def icon(assigns) do
    BoonWeb.CoreComponents.icon(assigns)
  end
end
