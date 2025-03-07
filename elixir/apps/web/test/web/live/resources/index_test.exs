defmodule Web.Live.Resources.IndexTest do
  use Web.ConnCase, async: true

  setup do
    account = Fixtures.Accounts.create_account()
    identity = Fixtures.Auth.create_identity(account: account, actor: [type: :account_admin_user])

    %{
      account: account,
      identity: identity
    }
  end

  test "redirects to sign in page for unauthorized user", %{account: account, conn: conn} do
    assert live(conn, ~p"/#{account}/resources") ==
             {:error,
              {:redirect,
               %{
                 to: ~p"/#{account}",
                 flash: %{"error" => "You must log in to access this page."}
               }}}
  end

  test "renders breadcrumbs item", %{
    account: account,
    identity: identity,
    conn: conn
  } do
    {:ok, _lv, html} =
      conn
      |> authorize_conn(identity)
      |> live(~p"/#{account}/resources")

    assert item = Floki.find(html, "[aria-label='Breadcrumb']")
    breadcrumbs = String.trim(Floki.text(item))
    assert breadcrumbs =~ "Resources"
  end

  test "renders add resource button", %{
    account: account,
    identity: identity,
    conn: conn
  } do
    {:ok, _lv, html} =
      conn
      |> authorize_conn(identity)
      |> live(~p"/#{account}/resources")

    assert button = Floki.find(html, "a[href='/#{account.id}/resources/new']")
    assert Floki.text(button) =~ "Add Resource"
  end

  test "renders resources table", %{
    account: account,
    identity: identity,
    conn: conn
  } do
    group = Fixtures.Gateways.create_group(account: account)

    resource =
      Fixtures.Resources.create_resource(
        account: account,
        connections: [%{gateway_group_id: group.id}]
      )

    {:ok, lv, _html} =
      conn
      |> authorize_conn(identity)
      |> live(~p"/#{account}/resources")

    resource_rows =
      lv
      |> element("#resources")
      |> render()
      |> table_to_map()

    Enum.each(resource_rows, fn row ->
      assert row["name"] =~ resource.name
      assert row["address"] =~ resource.address
      assert row["gateway instance group"] =~ group.name_prefix
    end)

    # TODO: add assertion for Authorized Groups column
  end
end
