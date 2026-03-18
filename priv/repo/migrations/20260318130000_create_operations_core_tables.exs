defmodule Boon.Repo.Migrations.CreateOperationsCoreTables do
  use Ecto.Migration

  def change do
    execute("CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"", "")

    create table(:work_packages, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :number, :text, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:work_packages, [:number])

    create table(:purchase_orders, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :po_number, :text, null: false
      add :order_date, :date
      add :revision_date, :date
      add :reference, :text

      add :work_package_id, references(:work_packages, type: :uuid, on_delete: :delete_all),
        null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:purchase_orders, [:work_package_id])

    create unique_index(:purchase_orders, [:work_package_id, :po_number, :revision_date],
             name: :purchase_orders_work_package_id_po_number_revision_date_index
           )

    create table(:purchase_order_lines, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :line, :integer, null: false
      add :item_number, :text, null: false
      add :ship_date, :date
      add :quantity, :integer, null: false

      add :purchase_order_id, references(:purchase_orders, type: :uuid, on_delete: :delete_all),
        null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:purchase_order_lines, [:purchase_order_id])
    create unique_index(:purchase_order_lines, [:purchase_order_id, :line])
  end
end
