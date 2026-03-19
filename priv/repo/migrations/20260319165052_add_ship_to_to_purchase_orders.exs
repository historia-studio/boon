defmodule Boon.Repo.Migrations.AddShipToToPurchaseOrders do
  use Ecto.Migration

  def change do
    alter table(:purchase_orders) do
      add :ship_to, :text
    end
  end
end
