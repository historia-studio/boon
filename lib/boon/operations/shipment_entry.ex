defmodule Boon.Operations.ShipmentEntry do
  use Ash.Resource,
    domain: Boon.Operations,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("shipment_entries")
    repo(Boon.Repo)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)

      accept([
        :pallet_tag_token,
        :pair_number,
        :pallet_type,
        :po_number,
        :tank_item_number,
        :cabinet_item_number,
        :work_package_id,
        :purchase_order_id,
        :shipment_id
      ])
    end
  end

  identities do
    identity(:unique_typed_pallet_per_purchase_order, [
      :purchase_order_id,
      :pair_number,
      :pallet_type
    ])

    identity(:unique_pallet_tag_token, [:pallet_tag_token])
  end

  attributes do
    uuid_primary_key(:id)

    attribute :pallet_tag_token, :string do
      allow_nil?(false)
      public?(true)
      constraints(trim?: true, min_length: 1)
    end

    attribute :pair_number, :integer do
      allow_nil?(false)
      public?(true)
      constraints(min: 1)
    end

    attribute :pallet_type, :string do
      allow_nil?(false)
      public?(true)
      constraints(trim?: true, match: ~r/^(tank|cabinet|bundle)$/)
    end

    attribute :po_number, :string do
      allow_nil?(false)
      public?(true)
    end

    attribute :tank_item_number, :string do
      allow_nil?(true)
      public?(true)
    end

    attribute :cabinet_item_number, :string do
      allow_nil?(true)
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
      allow_nil?(false)
      public?(true)
      attribute_public?(true)
    end

    belongs_to :shipment, Boon.Operations.Shipment do
      allow_nil?(false)
      public?(true)
      attribute_public?(true)
    end
  end
end
