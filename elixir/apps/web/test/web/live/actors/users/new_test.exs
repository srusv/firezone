defmodule Web.Live.Actors.User.NewTest do
  use Web.ConnCase, async: true

  setup do
    Domain.Config.put_system_env_override(:outbound_email_adapter, Swoosh.Adapters.Postmark)

    account = Fixtures.Accounts.create_account()
    actor = Fixtures.Actors.create_actor(type: :account_admin_user, account: account)
    provider = Fixtures.Auth.create_email_provider(account: account)
    identity = Fixtures.Auth.create_identity(account: account, provider: provider, actor: actor)

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
    assert live(conn, ~p"/#{account}/actors/users/new") ==
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
      |> live(~p"/#{account}/actors/users/new")

    assert item = Floki.find(html, "[aria-label='Breadcrumb']")
    breadcrumbs = String.trim(Floki.text(item))
    assert breadcrumbs =~ "Actors"
    assert breadcrumbs =~ "Add"
    assert breadcrumbs =~ "User"
  end

  test "renders form", %{
    account: account,
    identity: identity,
    conn: conn
  } do
    {:ok, lv, _html} =
      conn
      |> authorize_conn(identity)
      |> live(~p"/#{account}/actors/users/new")

    form = form(lv, "form")

    assert find_inputs(form) == [
             "actor[name]",
             "actor[type]"
           ]

    Fixtures.Actors.create_group(account: account)

    {:ok, lv, _html} =
      conn
      |> authorize_conn(identity)
      |> live(~p"/#{account}/actors/users/new")

    form = form(lv, "form")

    assert find_inputs(form) == [
             "actor[memberships][]",
             "actor[name]",
             "actor[type]"
           ]
  end

  test "renders changeset errors on input change", %{
    account: account,
    identity: identity,
    conn: conn
  } do
    attrs = Fixtures.Actors.actor_attrs() |> Map.take([:name])

    {:ok, lv, _html} =
      conn
      |> authorize_conn(identity)
      |> live(~p"/#{account}/actors/users/new")

    lv
    |> form("form", actor: attrs)
    |> validate_change(%{actor: %{name: String.duplicate("a", 555)}}, fn form, _html ->
      assert form_validation_errors(form) == %{
               "actor[name]" => ["should be at most 512 character(s)"]
             }
    end)
  end

  test "renders changeset errors on submit", %{
    account: account,
    identity: identity,
    conn: conn
  } do
    {:ok, lv, _html} =
      conn
      |> authorize_conn(identity)
      |> live(~p"/#{account}/actors/users/new")

    assert lv
           |> form("form", actor: %{})
           |> render_submit()
           |> form_validation_errors() == %{
             "actor[name]" => ["can't be blank"]
           }
  end

  test "creates a new actor on valid attrs", %{
    account: account,
    actor: actor,
    identity: identity,
    conn: conn
  } do
    group1 = Fixtures.Actors.create_group(account: account)
    Fixtures.Actors.create_membership(actor: actor, group: group1)

    group2 = Fixtures.Actors.create_group(account: account)

    attrs = %{
      name: Fixtures.Actors.actor_attrs().name,
      memberships: [group1.id, group2.id]
    }

    {:ok, lv, _html} =
      conn
      |> authorize_conn(identity)
      |> live(~p"/#{account}/actors/users/new")

    assert lv
           |> form("form", actor: attrs)
           |> render_submit()
           |> form_validation_errors() == %{}

    assert actor = Repo.get_by(Domain.Actors.Actor, name: attrs.name)

    assert_redirect(lv, ~p"/#{account}/actors/users/#{actor}/new_identity")
  end
end
