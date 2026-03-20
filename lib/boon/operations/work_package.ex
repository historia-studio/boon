defmodule Boon.Operations.WorkPackage do
  use Ash.Resource,
    domain: Boon.Operations,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("work_packages")
    repo(Boon.Repo)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)
      accept([:number])
    end

    update :update do
      primary?(true)
      accept([:number])
    end
  end

  identities do
    identity(:unique_number, [:number])
  end

  attributes do
    uuid_primary_key(:id)

    attribute :number, :string do
      allow_nil?(false)
      public?(true)
      constraints(trim?: true, min_length: 1)
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    has_many :purchase_orders, Boon.Operations.PurchaseOrder do
      public?(true)
      destination_attribute(:work_package_id)
    end

    has_many :print_jobs, Boon.Operations.PrintJob do
      public?(true)
      destination_attribute(:work_package_id)
    end
  end
end
