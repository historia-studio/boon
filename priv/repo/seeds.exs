# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Boon.Repo.insert!(%Boon.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

username =
  System.get_env("BOON_SHARED_USERNAME") ||
    System.get_env("BOON_SHARED_USER_EMAIL") ||
    "operators"

password =
  System.get_env("BOON_SHARED_USER_PASSWORD") || "change-immediately"

_user = Boon.Accounts.ensure_user!(username, password)
