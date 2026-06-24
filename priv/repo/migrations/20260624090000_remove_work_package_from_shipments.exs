defmodule Boon.Repo.Migrations.RemoveWorkPackageFromShipments do
  use Ecto.Migration

  def change do
    alter table(:shipments) do
      remove :work_package_id
    end

    execute(
      "ALTER TABLE print_jobs ALTER COLUMN work_package_id DROP NOT NULL",
      "ALTER TABLE print_jobs ALTER COLUMN work_package_id SET NOT NULL"
    )
  end
end
