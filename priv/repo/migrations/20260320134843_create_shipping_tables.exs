defmodule Boon.Repo.Migrations.CreateShippingTables do
  use Ecto.Migration

  def change do
    alter table(:purchase_orders) do
      add :shipped_at, :utc_datetime_usec
    end

    create table(:shipments, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :confirmed_at, :utc_datetime_usec, null: false
      add :submitted_from, :text
      add :entry_count, :integer, null: false

      add :work_package_id, references(:work_packages, type: :uuid, on_delete: :delete_all),
        null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:shipments, [:work_package_id])
    create index(:purchase_orders, [:shipped_at])

    create table(:shipment_entries, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :pallet_tag_token, :text, null: false
      add :pair_number, :integer, null: false
      add :po_number, :text, null: false
      add :tank_item_number, :text, null: false
      add :cabinet_item_number, :text, null: false

      add :work_package_id, references(:work_packages, type: :uuid, on_delete: :delete_all),
        null: false

      add :purchase_order_id, references(:purchase_orders, type: :uuid, on_delete: :delete_all),
        null: false

      add :shipment_id, references(:shipments, type: :uuid, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:shipment_entries, [:work_package_id])
    create index(:shipment_entries, [:purchase_order_id])
    create index(:shipment_entries, [:shipment_id])
    create unique_index(:shipment_entries, [:pallet_tag_token])
    create unique_index(:shipment_entries, [:purchase_order_id, :pair_number])
  end
end
