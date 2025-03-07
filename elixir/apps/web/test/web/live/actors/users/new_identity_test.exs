defmodule Web.Live.Actors.User.NewIdentityTest do
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
    actor: actor,
    conn: conn
  } do
    assert live(conn, ~p"/#{account}/actors/users/#{actor}/new_identity") ==
             {:error,
              {:redirect,
               %{
                 to: ~p"/#{account}",
                 flash: %{"error" => "You must log in to access this page."}
               }}}
  end

  test "renders breadcrumbs item", %{
    account: account,
    actor: actor,
    identity: identity,
    conn: conn
  } do
    {:ok, _lv, html} =
      conn
      |> authorize_conn(identity)
      |> live(~p"/#{account}/actors/users/#{actor}/new_identity")

    assert item = Floki.find(html, "[aria-label='Breadcrumb']")
    breadcrumbs = String.trim(Floki.text(item))
    assert breadcrumbs =~ "Actors"
    assert breadcrumbs =~ actor.name
    assert breadcrumbs =~ "Add Identity"
  end

  test "renders form", %{
    account: account,
    actor: actor,
    identity: identity,
    conn: conn
  } do
    {:ok, lv, _html} =
      conn
      |> authorize_conn(identity)
      |> live(~p"/#{account}/actors/users/#{actor}/new_identity")

    assert lv
           |> form("form")
           |> find_inputs() == [
             "identity[provider_id]",
             "identity[provider_identifier]"
           ]
  end

  test "changes form depending on selected provider", %{
    account: account,
    actor: actor,
    identity: identity,
    conn: conn
  } do
    provider = Fixtures.Auth.create_userpass_provider(account: account)

    {:ok, lv, _html} =
      conn
      |> authorize_conn(identity)
      |> live(~p"/#{account}/actors/users/#{actor}/new_identity")

    lv
    |> form("form", identity: %{provider_id: provider.id})
    |> render_change()

    assert lv
           |> form("form")
           |> find_inputs() == [
             "identity[provider_id]",
             "identity[provider_identifier]",
             "identity[provider_virtual_state][_persistent_id]",
             "identity[provider_virtual_state][password]",
             "identity[provider_virtual_state][password_confirmation]"
           ]
  end

  test "renders changeset errors on input change", %{
    account: account,
    actor: actor,
    identity: identity,
    conn: conn
  } do
    {:ok, lv, _html} =
      conn
      |> authorize_conn(identity)
      |> live(~p"/#{account}/actors/users/#{actor}/new_identity")

    lv
    |> form("form", identity: %{})
    |> validate_change(%{identity: %{provider_identifier: ""}}, fn form, _html ->
      assert form_validation_errors(form) == %{
               "identity[provider_identifier]" => ["can't be blank"]
             }
    end)
  end

  test "renders changeset errors on submit", %{
    account: account,
    actor: actor,
    identity: identity,
    conn: conn
  } do
    attrs = %{provider_identifier: ""}

    {:ok, lv, _html} =
      conn
      |> authorize_conn(identity)
      |> live(~p"/#{account}/actors/users/#{actor}/new_identity")

    assert lv
           |> form("form", identity: attrs)
           |> render_submit()
           |> form_validation_errors() == %{
             "identity[provider_identifier]" => ["can't be blank"]
           }
  end

  test "creates a new actor on valid attrs", %{
    account: account,
    actor: actor,
    identity: identity,
    conn: conn
  } do
    attrs = %{
      provider_identifier: Fixtures.Auth.email()
    }

    {:ok, lv, _html} =
      conn
      |> authorize_conn(identity)
      |> live(~p"/#{account}/actors/users/#{actor}/new_identity")

    assert lv
           |> form("form", identity: attrs)
           |> render_submit()
           |> form_validation_errors() == %{}

    assert identity =
             Repo.get_by(Domain.Auth.Identity, provider_identifier: attrs.provider_identifier)

    assert_redirect(lv, ~p"/#{account}/actors/#{identity.actor_id}")
  end
end
