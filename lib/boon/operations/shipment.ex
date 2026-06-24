defmodule Boon.Operations.Shipment do
  use Ash.Resource,
    domain: Boon.Operations,
    data_layer: AshPostgres.DataLayer

  postgres do
    table("shipments")
    repo(Boon.Repo)
  end

  actions do
    defaults([:read, :destroy])

    create :create do
      primary?(true)
      accept([:confirmed_at, :submitted_from, :entry_count])
    end

    update :update do
      primary?(true)
      accept([:confirmed_at, :submitted_from, :entry_count])
    end
  end

  attributes do
    uuid_primary_key(:id)

    attribute :confirmed_at, :utc_datetime_usec do
      allow_nil?(false)
      public?(true)
    end

    attribute :submitted_from, :string do
      public?(true)
    end

    attribute :entry_count, :integer do
      allow_nil?(false)
      public?(true)
      constraints(min: 1)
    end

    create_timestamp(:inserted_at)
    update_timestamp(:updated_at)
  end

  relationships do
    has_many :entries, Boon.Operations.ShipmentEntry do
      public?(true)
      destination_attribute(:shipment_id)
    end
  end
end
