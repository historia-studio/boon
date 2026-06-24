defmodule Boon.Repo.Migrations.AllowNullableShipmentEntryItemNumbers do
  use Ecto.Migration

  def change do
    alter table(:shipment_entries) do
      modify :tank_item_number, :text, null: true
      modify :cabinet_item_number, :text, null: true
    end
  end
end
