defmodule Boon.Repo.Migrations.DropUniqueLineNumberPerPurchaseOrder do
  use Ecto.Migration

  def change do
    drop_if_exists unique_index(:purchase_order_lines, [:purchase_order_id, :line])
  end
end
