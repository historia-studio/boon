defmodule Boon.Repo.Migrations.AddPalletTypeToShipmentEntries do
  use Ecto.Migration

  def change do
    alter table(:shipment_entries) do
      add :pallet_type, :text, null: false, default: "bundle"
    end

    drop_if_exists unique_index(:shipment_entries, [:purchase_order_id, :pair_number])
    create unique_index(:shipment_entries, [:purchase_order_id, :pair_number, :pallet_type])

    execute(
      "ALTER TABLE shipment_entries ALTER COLUMN pallet_type DROP DEFAULT",
      "ALTER TABLE shipment_entries ALTER COLUMN pallet_type SET DEFAULT 'bundle'"
    )
  end
end
