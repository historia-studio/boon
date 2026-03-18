defmodule Boon.Cldr do
  use Cldr,
    default_locale: "en",
    locales: ["en"],
    providers: [Cldr.Number, Money]
end
