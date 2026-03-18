defmodule Boon.Operations.PurchaseOrderLine do
  use Ash.Resource,
    domain: Boon.Operations,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("purchase_order_lines")
    repo(Boon.Repo)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)
      accept([:line, :item_number, :ship_date, :quantity, :purchase_order_id])
    end

    update :update do
      primary?(true)
      accept([:line, :item_number, :ship_date, :quantity, :purchase_order_id])
    end
  end

  identities do
    identity(:unique_line_per_purchase_order, [:purchase_order_id, :line])
  end

  attributes do
    uuid_primary_key(:id)

    attribute :line, :integer do
      allow_nil?(false)
      public?(true)
      constraints(min: 1)
    end

    attribute :item_number, :string do
      allow_nil?(false)
      public?(true)
      constraints(min_length: 1)
    end

    attribute :ship_date, :date do
      public?(true)
    end

    attribute :quantity, :integer do
      allow_nil?(false)
      public?(true)
      constraints(min: 1)
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    belongs_to :purchase_order, Boon.Operations.PurchaseOrder do
      allow_nil?(false)
      public?(true)
      attribute_public?(true)
    end
  end
end
