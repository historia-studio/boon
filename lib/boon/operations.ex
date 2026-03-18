defmodule Boon.Operations do
  use Ash.Domain

  resources do
    resource(Boon.Operations.WorkPackage)
    resource(Boon.Operations.PurchaseOrder)
    resource(Boon.Operations.PurchaseOrderLine)
  end
end
