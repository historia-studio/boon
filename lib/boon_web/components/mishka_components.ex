defmodule BoonWeb.Components.MishkaComponents do
  defmacro __using__(_) do
    quote do
      import BoonWeb.Components.Button,
        only: [button_group: 1, button: 1, input_button: 1, button_link: 1, back: 1]

      import BoonWeb.Components.Card,
        only: [card: 1, card_title: 1, card_media: 1, card_content: 1, card_footer: 1]

      import BoonWeb.Components.Table, only: [table: 1, th: 1, tr: 1, td: 1]

      import BoonWeb.Components.Badge,
        only: [badge: 1, hide_badge: 1, hide_badge: 2, show_badge: 1, show_badge: 2]

      import BoonWeb.Components.InputField, only: [input: 1, error: 1]
      import BoonWeb.Components.FileField, only: [file: 1]
    end
  end
end
