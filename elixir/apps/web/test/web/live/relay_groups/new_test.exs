defmodule Web.Live.RelayGroups.NewTest do
  use Web.ConnCase, async: true

  setup do
    account = Fixtures.Accounts.create_account()
    actor = Fixtures.Actors.create_actor(type: :account_admin_user, account: account)
    identity = Fixtures.Auth.create_identity(account: account, actor: actor)

    %{
      account: account,
      actor: actor,
      identity: identity
    }
  end

  test "redirects to sign in page for unauthorized user", %{
    account: account,
    conn: conn
  } do
    assert live(conn, ~p"/#{account}/relay_groups/new") ==
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
      |> live(~p"/#{account}/relay_groups/new")

    assert item = Floki.find(html, "[aria-label='Breadcrumb']")
    breadcrumbs = String.trim(Floki.text(item))
    assert breadcrumbs =~ "Relay Instance Groups"
    assert breadcrumbs =~ "Add"
  end

  test "renders form", %{
    account: account,
    identity: identity,
    conn: conn
  } do
    {:ok, lv, _html} =
      conn
      |> authorize_conn(identity)
      |> live(~p"/#{account}/relay_groups/new")

    form = form(lv, "form")

    assert find_inputs(form) == [
             "group[name]"
           ]
  end

  test "renders changeset errors on input change", %{
    account: account,
    identity: identity,
    conn: conn
  } do
    attrs = Fixtures.Relays.group_attrs() |> Map.take([:name])

    {:ok, lv, _html} =
      conn
      |> authorize_conn(identity)
      |> live(~p"/#{account}/relay_groups/new")

    lv
    |> form("form", group: attrs)
    |> validate_change(%{group: %{name: String.duplicate("a", 256)}}, fn form, _html ->
      assert form_validation_errors(form) == %{
               "group[name]" => ["should be at most 64 character(s)"]
             }
    end)
  end

  test "renders changeset errors on submit", %{
    account: account,
    identity: identity,
    conn: conn
  } do
    other_relay = Fixtures.Relays.create_group(account: account)
    attrs = %{name: other_relay.name}

    {:ok, lv, _html} =
      conn
      |> authorize_conn(identity)
      |> live(~p"/#{account}/relay_groups/new")

    assert lv
           |> form("form", group: attrs)
           |> render_submit()
           |> form_validation_errors() == %{
             "group[name]" => ["has already been taken"]
           }
  end

  test "creates a new group on valid attrs and redirects when relay is connected", %{
    account: account,
    identity: identity,
    conn: conn
  } do
    attrs = Fixtures.Relays.group_attrs() |> Map.take([:name])

    {:ok, lv, _html} =
      conn
      |> authorize_conn(identity)
      |> live(~p"/#{account}/relay_groups/new")

    html =
      lv
      |> form("form", group: attrs)
      |> render_submit()

    assert html =~ "Select deployment method"
    assert html =~ "PORTAL_TOKEN="
    assert html =~ "docker run"
    assert html =~ "Waiting for relay connection..."

    token = Regex.run(~r/PORTAL_TOKEN=([^ ]+)/, html) |> List.last()
    assert {:ok, _token} = Domain.Relays.authorize_relay(token)

    group = Repo.get_by(Domain.Relays.Group, name: attrs.name) |> Repo.preload(:tokens)
    relay = Fixtures.Relays.create_relay(account: account, group: group)
    Domain.Relays.connect_relay(relay, "foo")

    assert assert_redirect(lv, ~p"/#{account}/relay_groups/#{group}")
  end
end
