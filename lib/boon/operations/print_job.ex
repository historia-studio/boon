defmodule Boon.Operations.PrintJob do
  use Ash.Resource,
    domain: Boon.Operations,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("print_jobs")
    repo(Boon.Repo)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)

      accept([
        :document_type,
        :target_printer,
        :status,
        :error_details,
        :payload_path,
        :work_package_id,
        :purchase_order_id
      ])
    end

    update :update do
      primary?(true)

      accept([
        :document_type,
        :target_printer,
        :status,
        :error_details,
        :payload_path,
        :work_package_id,
        :purchase_order_id
      ])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :document_type, :string do
      allow_nil?(false)
      public?(true)
      constraints(trim?: true, min_length: 1)
    end

    attribute :target_printer, :string do
      allow_nil?(false)
      public?(true)
      constraints(trim?: true, min_length: 1)
    end

    attribute :status, :string do
      allow_nil?(false)
      public?(true)
      constraints(trim?: true, min_length: 1)
    end

    attribute :error_details, :string do
      public?(true)
    end

    attribute :payload_path, :string do
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

    belongs_to :purchase_order, Boon.Operations.PurchaseOrder do
      public?(true)
      attribute_public?(true)
    end
  end
end
