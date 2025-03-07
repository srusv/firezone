defmodule Domain.Flows.Flow.Query do
  use Domain, :query

  def all do
    from(flows in Domain.Flows.Flow, as: :flows)
  end

  def by_id(queryable \\ all(), id) do
    where(queryable, [flows: flows], flows.id == ^id)
  end

  def by_account_id(queryable \\ all(), account_id) do
    where(queryable, [flows: flows], flows.account_id == ^account_id)
  end

  def by_policy_id(queryable \\ all(), policy_id) do
    where(queryable, [flows: flows], flows.policy_id == ^policy_id)
  end

  def by_resource_id(queryable \\ all(), resource_id) do
    where(queryable, [flows: flows], flows.resource_id == ^resource_id)
  end

  def by_client_id(queryable \\ all(), client_id) do
    where(queryable, [flows: flows], flows.client_id == ^client_id)
  end

  def by_gateway_id(queryable \\ all(), gateway_id) do
    where(queryable, [flows: flows], flows.gateway_id == ^gateway_id)
  end
end
