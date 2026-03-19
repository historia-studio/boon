defmodule Boon.Operations do
  use Ash.Domain

  alias Boon.Operations.{PurchaseOrder, PurchaseOrderLine, WorkPackage}
  alias Boon.Repo

  resources do
    resource(Boon.Operations.WorkPackage)
    resource(Boon.Operations.PurchaseOrder)
    resource(Boon.Operations.PurchaseOrderLine)
  end

  def list_work_packages do
    WorkPackage
    |> Ash.Query.sort(inserted_at: :desc)
    |> Ash.Query.load(purchase_orders: :lines)
    |> Ash.read!()
    |> Enum.map(&sort_work_package/1)
  end

  def get_work_package!(id) do
    WorkPackage
    |> Ash.get!(id, load: [purchase_orders: :lines])
    |> sort_work_package()
  end

  def dashboard_counts do
    work_packages = list_work_packages()

    purchase_orders =
      Enum.reduce(work_packages, 0, fn work_package, total ->
        total + length(work_package.purchase_orders)
      end)

    purchase_order_lines =
      Enum.reduce(work_packages, 0, fn work_package, total ->
        total +
          Enum.reduce(work_package.purchase_orders, 0, fn purchase_order, line_total ->
            line_total + length(purchase_order.lines)
          end)
      end)

    %{
      work_packages: length(work_packages),
      purchase_orders: purchase_orders,
      purchase_order_lines: purchase_order_lines
    }
  end

  def create_work_package_entry(attrs) do
    Repo.transaction(fn ->
      with {:ok, work_package} <- Ash.create(WorkPackage, %{number: attrs.number}),
           {:ok, _purchase_orders} <- create_purchase_orders(work_package, attrs.purchase_orders) do
        get_work_package!(work_package.id)
      else
        {:error, error} -> Repo.rollback(format_error(error))
      end
    end)
    |> case do
      {:ok, work_package} -> {:ok, work_package}
      {:error, errors} when is_list(errors) -> {:error, errors}
      {:error, error} -> {:error, [format_error(error)]}
    end
  end

  defp create_purchase_orders(work_package, purchase_orders) do
    purchase_orders
    |> Enum.reduce_while({:ok, []}, fn purchase_order_attrs, {:ok, created_purchase_orders} ->
      case create_purchase_order(work_package, purchase_order_attrs) do
        {:ok, purchase_order} -> {:cont, {:ok, [purchase_order | created_purchase_orders]}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp create_purchase_order(work_package, purchase_order_attrs) do
    attrs = %{
      po_number: purchase_order_attrs.po_number,
      order_date: purchase_order_attrs.order_date,
      revision_date: purchase_order_attrs.revision_date,
      reference: purchase_order_attrs.reference,
      ship_to: purchase_order_attrs.ship_to,
      work_package_id: work_package.id
    }

    with {:ok, purchase_order} <- Ash.create(PurchaseOrder, attrs),
         {:ok, _lines} <- create_purchase_order_lines(purchase_order, purchase_order_attrs.lines) do
      {:ok, purchase_order}
    end
  end

  defp create_purchase_order_lines(purchase_order, lines) do
    lines
    |> Enum.reduce_while({:ok, []}, fn line_attrs, {:ok, created_lines} ->
      attrs = %{
        line: line_attrs.line,
        item_number: line_attrs.item_number,
        ship_date: line_attrs.ship_date,
        quantity: line_attrs.quantity,
        purchase_order_id: purchase_order.id
      }

      case Ash.create(PurchaseOrderLine, attrs) do
        {:ok, line} -> {:cont, {:ok, [line | created_lines]}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp sort_work_package(work_package) do
    purchase_orders =
      work_package.purchase_orders
      |> Enum.map(fn purchase_order ->
        %{purchase_order | lines: Enum.sort_by(purchase_order.lines, & &1.line)}
      end)
      |> Enum.sort_by(&{&1.order_date || ~D[9999-12-31], &1.po_number})

    %{work_package | purchase_orders: purchase_orders}
  end

  defp format_error(%_{} = error), do: Exception.message(error)
  defp format_error(error), do: inspect(error)
end
