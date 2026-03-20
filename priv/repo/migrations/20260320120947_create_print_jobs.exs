defmodule Boon.Repo.Migrations.CreatePrintJobs do
  use Ecto.Migration

  def change do
    create table(:print_jobs, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("uuid_generate_v4()")
      add :document_type, :text, null: false
      add :target_printer, :text, null: false
      add :status, :text, null: false
      add :error_details, :text
      add :payload_path, :text

      add :work_package_id, references(:work_packages, type: :uuid, on_delete: :delete_all),
        null: false

      add :purchase_order_id, references(:purchase_orders, type: :uuid, on_delete: :nilify_all)

      timestamps(type: :utc_datetime_usec)
    end

    create index(:print_jobs, [:work_package_id])
    create index(:print_jobs, [:purchase_order_id])
    create index(:print_jobs, [:status])
  end
end
