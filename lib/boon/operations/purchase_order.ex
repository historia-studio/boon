defmodule Boon.Operations.PurchaseOrder do
  use Ash.Resource,
    domain: Boon.Operations,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("purchase_orders")
    repo(Boon.Repo)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)
      accept([:po_number, :order_date, :revision_date, :reference, :ship_to, :work_package_id])
    end

    update :update do
      primary?(true)
      accept([:po_number, :order_date, :revision_date, :reference, :ship_to, :work_package_id])
    end
  end

  identities do
    identity(:unique_po_per_work_package, [:work_package_id, :po_number, :revision_date])
  end

  attributes do
    uuid_primary_key(:id)

    attribute :po_number, :string do
      allow_nil?(false)
      public?(true)
      constraints(trim?: true, min_length: 1)
    end

    attribute :order_date, :date do
      public?(true)
    end

    attribute :revision_date, :date do
      public?(true)
    end

    attribute :reference, :string do
      public?(true)
    end

    attribute :ship_to, :string do
      public?(true)
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :work_package, Boon.Operations.WorkPackage do
      allow_nil?(false)
      public?(true)
      attribute_public?(true)
    end

    has_many :lines, Boon.Operations.PurchaseOrderLine do
      public?(true)
      destination_attribute(:purchase_order_id)
    end

    has_many :print_jobs, Boon.Operations.PrintJob do
      public?(true)
      destination_attribute(:purchase_order_id)
    end
  end
end
