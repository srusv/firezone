defmodule Domain.Fixtures.Clients do
  use Domain.Fixture
  alias Domain.Clients

  def client_attrs(attrs \\ %{}) do
    Enum.into(attrs, %{
      external_id: Ecto.UUID.generate(),
      name: "client-#{unique_integer()}",
      public_key: unique_public_key()
    })
  end

  def create_client(attrs \\ %{}) do
    attrs = client_attrs(attrs)

    {account, attrs} =
      pop_assoc_fixture(attrs, :account, fn assoc_attrs ->
        if relation = attrs[:actor] || attrs[:identity] do
          Repo.get!(Domain.Accounts.Account, relation.account_id)
        else
          Fixtures.Accounts.create_account(assoc_attrs)
        end
      end)

    {actor, attrs} =
      pop_assoc_fixture(attrs, :actor, fn assoc_attrs ->
        assoc_attrs
        |> Enum.into(%{type: :account_admin_user, account: account})
        |> Fixtures.Actors.create_actor()
      end)

    {identity, attrs} =
      pop_assoc_fixture(attrs, :identity, fn assoc_attrs ->
        assoc_attrs
        |> Enum.into(%{account: account, actor: actor})
        |> Fixtures.Auth.create_identity()
      end)

    {subject, attrs} =
      pop_assoc_fixture(attrs, :subject, fn assoc_attrs ->
        assoc_attrs
        |> Enum.into(%{
          account: account,
          identity: identity,
          actor: [type: :account_admin_user]
        })
        |> Fixtures.Auth.create_subject()
      end)

    {:ok, client} = Clients.upsert_client(attrs, subject)
    %{client | online?: false}
  end

  def delete_client(client) do
    client = Repo.preload(client, :account)

    subject =
      Fixtures.Auth.create_subject(
        account: client.account,
        actor: [type: :account_admin_user]
      )

    {:ok, client} = Clients.delete_client(client, subject)
    client
  end
end
