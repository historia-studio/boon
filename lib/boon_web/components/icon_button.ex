defmodule BoonWeb.Components.IconButton do
  @moduledoc """
  Icon-only button wrapper around the shared button component.

  Keeps small utility actions visually consistent and accessible.
  """

  use Phoenix.Component

  @doc type: :component
  attr :id, :string, default: nil, doc: "DOM id"
  attr :icon, :string, required: true, doc: "Hero icon name"
  attr :label, :string, required: true, doc: "Accessible label and title"
  attr :type, :string, default: "button", values: ~w(button submit reset)
  attr :variant, :string, default: "ghost", doc: "Button variant"
  attr :color, :string, default: "warning", doc: "Button color"
  attr :size, :string, default: "extra_small", doc: "Button size"
  attr :class, :string, default: nil, doc: "Extra classes"
  attr :icon_class, :string, default: nil, doc: "Extra icon classes"

  attr :rest, :global,
    include:
      ~w(disabled form name value title aria-label phx-click phx-value-line-id phx-value-purchase-order-id phx-value-token),
    doc: "Global button attributes"

  def icon_button(assigns) do
    assigns =
      assign(
        assigns,
        :resolved_icon_class,
        Enum.join(Enum.reject([assigns.icon_class, "h-4 w-4"], &is_nil/1), " ")
      )

    ~H"""
    <BoonWeb.Components.Button.button
      id={@id}
      type={@type}
      variant={@variant}
      color={@color}
      size={@size}
      icon={@icon}
      icon_class={@resolved_icon_class}
      circle
      title={Map.get(@rest, :title) || Map.get(@rest, "title") || @label}
      aria-label={Map.get(@rest, "aria-label") || @label}
      class={@class}
      {Map.drop(@rest, [:title, "title", "aria-label"])}
    />
    """
  end
end
