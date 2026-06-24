defmodule Boon.Operations do
  use Ash.Domain

  import Ecto.Query, only: [from: 2]

  alias Boon.Operations.{
    PrintJob,
    PurchaseOrder,
    PurchaseOrderLine,
    Shipment,
    ShipmentEntry,
    WorkPackage
  }

  alias Boon.Printing.PalletTagBatch
  alias Boon.Shipping.PalletTagToken
  alias Boon.Repo

  resources do
    resource(Boon.Operations.WorkPackage)
    resource(Boon.Operations.PurchaseOrder)
    resource(Boon.Operations.PurchaseOrderLine)
    resource(Boon.Operations.PrintJob)
    resource(Boon.Operations.Shipment)
    resource(Boon.Operations.ShipmentEntry)
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

  def get_purchase_order!(id) do
    PurchaseOrder
    |> Ash.get!(id, load: [:lines, :work_package])
    |> sort_purchase_order()
  end

  def list_shipping_candidates_by_po(po_number_query) when is_binary(po_number_query) do
    normalized_query = normalize_shipping_candidate_query(po_number_query)

    if normalized_query == "" do
      []
    else
      shipped_keys = shipped_shipping_candidate_keys()

      list_work_packages()
      |> Enum.flat_map(fn work_package ->
        work_package.purchase_orders
        |> Enum.filter(&purchase_order_matches_query?(&1, normalized_query))
        |> Enum.flat_map(&shipping_candidates_from_purchase_order(work_package, &1, shipped_keys))
      end)
      |> Enum.sort_by(&{&1.po_number, &1.pair_number, &1.pallet_type})
    end
  end

  def list_shipments do
    Shipment
    |> Ash.Query.sort(confirmed_at: :desc, inserted_at: :desc)
    |> Ash.Query.load(entries: [:purchase_order, :work_package])
    |> Ash.read!()
    |> Enum.map(&sort_shipment/1)
  end

  def get_shipment!(id) do
    Shipment
    |> Ash.get!(id, load: [entries: [:purchase_order, :work_package]])
    |> sort_shipment()
  end

  def save_work_package_entry(attrs) do
    Repo.transaction(fn ->
      with {:ok, work_package, work_package_notifications} <-
             find_or_create_work_package(attrs.number),
           {:ok, _purchase_orders, purchase_order_notifications, work_package} <-
             merge_purchase_orders(work_package, attrs.purchase_orders) do
        {work_package, work_package_notifications ++ purchase_order_notifications}
      else
        {:error, error} -> Repo.rollback(error)
      end
    end)
    |> case do
      {:ok, {work_package, notifications}} ->
        notify(notifications)
        {:ok, work_package}

      {:error, errors} when is_list(errors) ->
        {:error, errors}

      {:error, error} ->
        {:error, [format_error(error)]}
    end
  end

  def delete_work_package(id) when is_binary(id) do
    case Ash.get(WorkPackage, id) do
      {:ok, nil} -> {:error, "That work package could not be found."}
      {:ok, work_package} -> delete_work_package(work_package)
      {:error, error} -> {:error, [format_error(error)]}
    end
  end

  def delete_work_package(%WorkPackage{} = work_package) do
    case Ash.destroy(work_package) do
      :ok -> :ok
      {:ok, _destroyed} -> :ok
      {:error, error} -> {:error, [format_error(error)]}
    end
  end

  def delete_purchase_order(id) when is_binary(id) do
    case Ash.get(PurchaseOrder, id) do
      {:ok, nil} -> {:error, ["That purchase order could not be found."]}
      {:ok, purchase_order} -> delete_purchase_order(purchase_order)
      {:error, error} -> {:error, [format_error(error)]}
    end
  end

  def delete_purchase_order(%PurchaseOrder{} = purchase_order) do
    case Ash.destroy(purchase_order) do
      :ok -> :ok
      {:ok, _destroyed} -> :ok
      {:error, error} -> {:error, [format_error(error)]}
    end
  end

  def delete_shipment(id) when is_binary(id) do
    case Ash.get(Shipment, id, load: [entries: :purchase_order]) do
      {:ok, nil} -> {:error, ["That shipment could not be found."]}
      {:ok, shipment} -> delete_shipment(shipment)
      {:error, error} -> {:error, [format_error(error)]}
    end
  end

  def delete_shipment(%Shipment{} = shipment) do
    Repo.transaction(fn ->
      shipment = Ash.load!(shipment, entries: :purchase_order)

      purchase_order_ids =
        shipment.entries
        |> Enum.map(& &1.purchase_order_id)
        |> Enum.uniq()

      with {:ok, destroy_notifications} <- destroy_resource(shipment),
           {:ok, shipping_status_notifications} <-
             sync_purchase_order_shipping_statuses(purchase_order_ids) do
        destroy_notifications ++ shipping_status_notifications
      else
        {:error, error} -> Repo.rollback(error)
      end
    end)
    |> case do
      {:ok, notifications} ->
        notify(notifications)
        :ok

      {:error, error} ->
        {:error, [format_error(error)]}
    end
  end

  def update_purchase_order_entry(id, attrs) when is_binary(id) do
    case Ash.get(PurchaseOrder, id, load: [:lines, :work_package]) do
      {:ok, nil} -> {:error, ["That purchase order could not be found."]}
      {:ok, purchase_order} -> update_purchase_order_entry(purchase_order, attrs)
      {:error, error} -> {:error, [format_error(error)]}
    end
  end

  def update_purchase_order_entry(%PurchaseOrder{} = purchase_order, attrs) do
    Repo.transaction(fn ->
      purchase_order =
        purchase_order
        |> Ash.load!([:lines, :work_package])
        |> sort_purchase_order()

      with {:ok, _updated_purchase_order, purchase_order_notifications} <-
             update_purchase_order_entry_in_transaction(purchase_order, attrs) do
        {get_purchase_order!(purchase_order.id), purchase_order_notifications}
      else
        {:error, error} -> Repo.rollback(error)
      end
    end)
    |> case do
      {:ok, {updated_purchase_order, notifications}} ->
        notify(notifications)
        {:ok, updated_purchase_order}

      {:error, errors} when is_list(errors) ->
        {:error, errors}

      {:error, error} ->
        {:error, [format_error(error)]}
    end
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

  def create_print_job(attrs) do
    Ash.create(PrintJob, attrs)
  end

  def create_shipment(attrs) do
    Repo.transaction(fn ->
      entries = Map.get(attrs, :entries, [])

      with {:ok, _first_entry} <- fetch_first_entry(entries),
           {:ok, shipment, shipment_notifications} <-
             create_resource(Shipment, %{
               confirmed_at: Map.get(attrs, :confirmed_at, DateTime.utc_now()),
               submitted_from: Map.get(attrs, :submitted_from),
               entry_count: length(entries)
             }),
           {:ok, created_entries, entry_notifications} <-
             create_shipment_entries(shipment, entries),
           {:ok, purchase_order_notifications} <-
             update_purchase_order_shipping_status(created_entries) do
        {%{shipment | entries: created_entries},
         shipment_notifications ++ entry_notifications ++ purchase_order_notifications}
      else
        {:error, error} -> Repo.rollback(format_error(error))
      end
    end)
    |> case do
      {:ok, {shipment, notifications}} ->
        notify(notifications)
        {:ok, shipment}

      {:error, errors} when is_list(errors) ->
        {:error, errors}

      {:error, error} ->
        {:error, [format_error(error)]}
    end
  end

  def create_shipment_from_tokens(tokens, attrs \\ %{}) when is_list(tokens) do
    with {:ok, %{tags: tags, errors: []}} <- resolve_shipping_tokens(tokens),
         {:ok, entries} <- shipment_entries_from_tags(tags) do
      create_shipment(%{
        confirmed_at: Map.get(attrs, :confirmed_at, DateTime.utc_now()),
        submitted_from: Map.get(attrs, :submitted_from),
        entries: entries
      })
    else
      {:ok, %{errors: errors}} when errors != [] -> {:error, errors}
      {:error, _error} = error -> error
    end
  end

  def resolve_shipping_token(token) when is_binary(token) do
    with {:ok, token_data} <- PalletTagToken.verify(token),
         work_package <-
           WorkPackage
           |> Ash.get!(token_data.work_package_id, load: [purchase_orders: :lines]),
         purchase_order <-
           Enum.find(work_package.purchase_orders, &(&1.id == token_data.purchase_order_id)),
         {:ok, tag} <-
           resolve_shipping_tag(
             work_package,
             purchase_order,
             token_data.pair_number,
             token_data.pallet_type
           ) do
      {:ok, tag}
    else
      nil -> {:error, "The scanned pallet tag does not match an existing purchase order."}
      {:error, _error} = error -> error
      error -> {:error, format_error(error)}
    end
  end

  def resolve_shipping_tokens(tokens) when is_list(tokens) do
    tokens
    |> Enum.reduce({[], []}, fn token, {resolved, errors} ->
      case resolve_shipping_token(token) do
        {:ok, tag} -> {[tag | resolved], errors}
        {:error, error} -> {resolved, [error | errors]}
      end
    end)
    |> then(fn {resolved, errors} ->
      {:ok, %{tags: Enum.reverse(resolved), errors: Enum.reverse(errors)}}
    end)
  end

  def shipment_draft_summary(tags) when is_list(tags) do
    %{
      work_packages: tags |> Enum.map(& &1.work_package_number) |> Enum.uniq(),
      purchase_orders: tags |> Enum.map(& &1.po_number) |> Enum.uniq(),
      staged_tags: length(tags)
    }
  end

  def create_work_package_entry(attrs) do
    Repo.transaction(fn ->
      with {:ok, work_package, work_package_notifications} <-
             create_resource(WorkPackage, %{number: attrs.number}),
           {:ok, _purchase_orders, purchase_order_notifications} <-
             create_purchase_orders(work_package, attrs.purchase_orders) do
        {get_work_package!(work_package.id),
         work_package_notifications ++ purchase_order_notifications}
      else
        {:error, error} -> Repo.rollback(error)
      end
    end)
    |> case do
      {:ok, {work_package, notifications}} ->
        notify(notifications)
        {:ok, work_package}

      {:error, errors} when is_list(errors) ->
        {:error, errors}

      {:error, error} ->
        {:error, [format_error(error)]}
    end
  end

  defp find_or_create_work_package(number) do
    case get_work_package_by_number(number) do
      nil ->
        with {:ok, work_package, notifications} <- create_resource(WorkPackage, %{number: number}) do
          {:ok, get_work_package!(work_package.id), notifications}
        end

      work_package ->
        {:ok, work_package, []}
    end
  end

  defp merge_purchase_orders(work_package, purchase_orders) do
    purchase_orders
    |> Enum.reduce_while({:ok, [], [], work_package}, fn purchase_order_attrs,
                                                         {:ok, saved_purchase_orders,
                                                          notifications, current_work_package} ->
      case merge_purchase_order(current_work_package, purchase_order_attrs) do
        {:ok, purchase_order, purchase_order_notifications, refreshed_work_package} ->
          {:cont,
           {:ok, [purchase_order | saved_purchase_orders],
            notifications ++ purchase_order_notifications, refreshed_work_package}}

        {:error, error} ->
          {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, purchase_orders, notifications, refreshed_work_package} ->
        {:ok, Enum.reverse(purchase_orders), notifications, refreshed_work_package}

      {:error, error} ->
        {:error, error}
    end
  end

  defp merge_purchase_order(work_package, purchase_order_attrs) do
    case find_matching_purchase_order(work_package, purchase_order_attrs) do
      nil ->
        with {:ok, purchase_order, purchase_order_notifications} <-
               create_purchase_order(work_package, purchase_order_attrs) do
          {:ok, purchase_order, purchase_order_notifications, get_work_package!(work_package.id)}
        end

      purchase_order ->
        with {:ok, updated_purchase_order, purchase_order_notifications} <-
               update_purchase_order_entry_in_transaction(purchase_order, purchase_order_attrs) do
          {:ok, updated_purchase_order, purchase_order_notifications,
           get_work_package!(work_package.id)}
        end
    end
  end

  defp create_purchase_orders(work_package, purchase_orders) do
    purchase_orders
    |> Enum.reduce_while({:ok, [], []}, fn purchase_order_attrs,
                                           {:ok, created_purchase_orders, notifications} ->
      case create_purchase_order(work_package, purchase_order_attrs) do
        {:ok, purchase_order, purchase_order_notifications} ->
          {:cont,
           {:ok, [purchase_order | created_purchase_orders],
            notifications ++ purchase_order_notifications}}

        {:error, error} ->
          {:halt, {:error, error}}
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

    with {:ok, purchase_order, purchase_order_notifications} <-
           create_resource(PurchaseOrder, attrs),
         {:ok, _lines, line_notifications} <-
           create_purchase_order_lines(purchase_order, purchase_order_attrs.lines) do
      {:ok, purchase_order, purchase_order_notifications ++ line_notifications}
    end
  end

  defp create_purchase_order_lines(purchase_order, lines) do
    lines
    |> Enum.reduce_while({:ok, [], []}, fn line_attrs, {:ok, created_lines, notifications} ->
      attrs = %{
        line: line_attrs.line,
        item_number: line_attrs.item_number,
        ship_date: line_attrs.ship_date,
        quantity: line_attrs.quantity,
        purchase_order_id: purchase_order.id
      }

      case create_resource(PurchaseOrderLine, attrs) do
        {:ok, line, line_notifications} ->
          {:cont, {:ok, [line | created_lines], notifications ++ line_notifications}}

        {:error, error} ->
          {:halt, {:error, error}}
      end
    end)
  end

  defp update_purchase_order_entry_in_transaction(purchase_order, attrs) do
    purchase_order_attrs = %{
      po_number: attrs.po_number,
      order_date: attrs.order_date,
      revision_date: attrs.revision_date,
      reference: attrs.reference,
      ship_to: attrs.ship_to,
      work_package_id: purchase_order.work_package_id
    }

    with {:ok, updated_purchase_order, purchase_order_notifications} <-
           update_resource(purchase_order, purchase_order_attrs),
         {:ok, destroy_notifications} <- delete_purchase_order_lines(purchase_order.lines),
         {:ok, _lines, line_notifications} <-
           create_purchase_order_lines(updated_purchase_order, attrs.lines) do
      {:ok, updated_purchase_order,
       purchase_order_notifications ++ destroy_notifications ++ line_notifications}
    end
  end

  defp find_matching_purchase_order(work_package, purchase_order_attrs) do
    Enum.find(work_package.purchase_orders, fn purchase_order ->
      purchase_order.po_number == purchase_order_attrs.po_number and
        purchase_order.revision_date == purchase_order_attrs.revision_date
    end)
  end

  defp get_work_package_by_number(number) do
    case from(work_package in "work_packages",
           where: work_package.number == ^number,
           select: work_package.id
         )
         |> Repo.one() do
      nil -> nil
      id -> get_work_package!(id)
    end
  end

  defp delete_purchase_order_lines(lines) do
    lines
    |> Enum.reduce_while({:ok, []}, fn line, {:ok, notifications} ->
      case destroy_resource(line) do
        {:ok, line_notifications} -> {:cont, {:ok, notifications ++ line_notifications}}
        {:error, error} -> {:halt, {:error, error}}
      end
    end)
  end

  defp sort_work_package(work_package) do
    purchase_orders =
      work_package.purchase_orders
      |> Enum.map(&sort_purchase_order/1)
      |> Enum.sort_by(&{&1.order_date || ~D[9999-12-31], &1.po_number})

    %{work_package | purchase_orders: purchase_orders}
  end

  defp sort_purchase_order(purchase_order) do
    %{purchase_order | lines: Enum.sort_by(purchase_order.lines, & &1.line)}
  end

  defp sort_shipment(shipment) do
    %{shipment | entries: Enum.sort_by(shipment.entries, &shipment_entry_sort_key/1)}
  end

  defp shipment_entry_sort_key(entry), do: {entry.po_number, entry.pair_number, entry.pallet_type}

  defp fetch_first_entry([first_entry | _rest]), do: {:ok, first_entry}

  defp fetch_first_entry([]),
    do: {:error, "A shipment must contain at least one scanned pallet tag."}

  defp shipped_shipping_candidate_keys do
    from(entry in "shipment_entries",
      select: {entry.purchase_order_id, entry.pair_number, entry.pallet_type}
    )
    |> Repo.all()
    |> MapSet.new()
  end

  defp purchase_order_matches_query?(purchase_order, normalized_query) do
    purchase_order.po_number
    |> to_string()
    |> String.upcase()
    |> String.contains?(normalized_query)
  end

  defp shipping_candidates_from_purchase_order(work_package, purchase_order, shipped_keys) do
    case PalletTagBatch.derive_purchase_order(purchase_order, work_package.number) do
      {:ok, tags} ->
        tags
        |> Enum.reject(fn tag ->
          MapSet.member?(shipped_keys, {purchase_order.id, tag.pair_number, tag.pallet_type})
        end)
        |> Enum.map(fn tag ->
          Map.merge(tag, %{
            work_package_id: work_package.id,
            purchase_order_id: purchase_order.id,
            pallet_tag_token:
              PalletTagToken.sign(
                work_package.id,
                purchase_order.id,
                tag.pair_number,
                tag.pallet_type
              )
          })
        end)

      {:error, _error} ->
        []
    end
  end

  defp normalize_shipping_candidate_query(po_number_query) do
    po_number_query
    |> String.trim()
    |> String.upcase()
  end

  defp shipment_entries_from_tags(tags) do
    {:ok,
     Enum.map(tags, fn tag ->
       %{
         pallet_tag_token: tag.pallet_tag_token,
         pair_number: tag.pair_number,
         pallet_type: tag.pallet_type,
         po_number: tag.po_number,
         tank_item_number: tag.tank_item_number,
         cabinet_item_number: tag.cabinet_item_number,
         work_package_id: tag.work_package_id,
         purchase_order_id: tag.purchase_order_id
       }
     end)}
  end

  defp create_shipment_entries(shipment, entries) do
    entries
    |> Enum.reduce_while({:ok, [], []}, fn entry, {:ok, created_entries, notifications} ->
      attrs = %{
        pallet_tag_token: entry.pallet_tag_token,
        pair_number: entry.pair_number,
        pallet_type: entry.pallet_type,
        po_number: entry.po_number,
        tank_item_number: normalize_shipment_entry_item_number(entry.tank_item_number),
        cabinet_item_number: normalize_shipment_entry_item_number(entry.cabinet_item_number),
        work_package_id: entry.work_package_id,
        purchase_order_id: entry.purchase_order_id,
        shipment_id: shipment.id
      }

      case create_resource(ShipmentEntry, attrs) do
        {:ok, created_entry, entry_notifications} ->
          {:cont, {:ok, [created_entry | created_entries], notifications ++ entry_notifications}}

        {:error, error} ->
          {:halt, {:error, error}}
      end
    end)
    |> case do
      {:ok, created_entries, notifications} ->
        {:ok, Enum.reverse(created_entries), notifications}

      {:error, error} ->
        {:error, error}
    end
  end

  defp normalize_shipment_entry_item_number(item_number) when item_number in [nil, ""], do: nil
  defp normalize_shipment_entry_item_number(item_number), do: item_number

  defp update_purchase_order_shipping_status(entries) do
    entries
    |> Enum.map(& &1.purchase_order_id)
    |> Enum.uniq()
    |> sync_purchase_order_shipping_statuses()
  end

  defp sync_purchase_order_shipping_statuses(purchase_order_ids) do
    purchase_order_ids
    |> Enum.reduce_while({:ok, []}, fn purchase_order_id, {:ok, notifications} ->
      purchase_order = PurchaseOrder |> Ash.get!(purchase_order_id, load: [:lines, :work_package])

      attrs =
        if purchase_order_fully_shipped?(purchase_order) do
          if is_nil(purchase_order.shipped_at) do
            %{shipped_at: DateTime.utc_now()}
          else
            nil
          end
        else
          if is_nil(purchase_order.shipped_at) do
            nil
          else
            %{shipped_at: nil}
          end
        end

      case attrs do
        nil ->
          {:cont, {:ok, notifications}}

        attrs ->
          case update_resource(purchase_order, attrs) do
            {:ok, _purchase_order, update_notifications} ->
              {:cont, {:ok, notifications ++ update_notifications}}

            {:error, error} ->
              {:halt, {:error, error}}
          end
      end
    end)
  end

  defp purchase_order_fully_shipped?(purchase_order) do
    expected_tag_count =
      case PalletTagBatch.derive_purchase_order(
             purchase_order,
             purchase_order.work_package.number
           ) do
        {:ok, tags} -> length(tags)
        {:error, _error} -> 0
      end

    if expected_tag_count == 0 do
      false
    else
      shipped_count =
        from(entry in "shipment_entries",
          where: entry.purchase_order_id == type(^purchase_order.id, Ecto.UUID),
          select: count()
        )
        |> Repo.one()

      shipped_count >= expected_tag_count
    end
  end

  defp resolve_shipping_tag(work_package, purchase_order, pair_number, pallet_type) do
    case PalletTagBatch.derive_purchase_order(purchase_order, work_package.number) do
      {:ok, tags} ->
        case Enum.find(tags, &(&1.pair_number == pair_number and &1.pallet_type == pallet_type)) do
          nil ->
            {:error,
             "The scanned pallet tag no longer matches the purchase order pallet identity."}

          tag ->
            {:ok,
             Map.merge(tag, %{
               work_package_id: work_package.id,
               purchase_order_id: purchase_order.id,
               pallet_tag_token:
                 PalletTagToken.sign(
                   work_package.id,
                   purchase_order.id,
                   pair_number,
                   pallet_type
                 )
             })}
        end

      {:error, error} ->
        {:error, error}
    end
  end

  defp create_resource(resource, attrs) do
    case Ash.create(resource, attrs, return_notifications?: true) do
      {:ok, record, notifications} -> {:ok, record, notifications}
      {:ok, record} -> {:ok, record, []}
      {:error, error} -> {:error, error}
    end
  end

  defp update_resource(resource, attrs) do
    case Ash.update(resource, attrs, return_notifications?: true) do
      {:ok, record, notifications} -> {:ok, record, notifications}
      {:ok, record} -> {:ok, record, []}
      {:error, error} -> {:error, error}
    end
  end

  defp destroy_resource(resource) do
    case Ash.destroy(resource, return_notifications?: true) do
      :ok -> {:ok, []}
      {:ok, _destroyed, notifications} -> {:ok, notifications}
      {:ok, _destroyed} -> {:ok, []}
      {:error, error} -> {:error, error}
    end
  end

  defp notify([]), do: :ok

  defp notify(notifications) when is_list(notifications) do
    Ash.Notifier.notify(notifications)
  end

  defp format_error(%{__exception__: true} = error), do: Exception.message(error)

  defp format_error(%{errors: errors}) when is_list(errors) do
    case errors
         |> Enum.map(&format_error/1)
         |> Enum.reject(&(&1 in [nil, ""]))
         |> Enum.join("; ") do
      "" -> inspect(errors)
      formatted -> formatted
    end
  end

  defp format_error([]), do: "Unknown error."
  defp format_error(%{error: error}), do: format_error(error)
  defp format_error(error), do: inspect(error)
end
