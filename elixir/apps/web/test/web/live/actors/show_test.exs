defmodule Web.Live.Actors.ShowTest do
  use Web.ConnCase, async: true

  test "redirects to sign in page for unauthorized user", %{conn: conn} do
    account = Fixtures.Accounts.create_account()
    actor = Fixtures.Actors.create_actor(type: :account_admin_user, account: account)

    assert live(conn, ~p"/#{account}/actors/#{actor}") ==
             {:error,
              {:redirect,
               %{
                 to: ~p"/#{account}",
                 flash: %{"error" => "You must log in to access this page."}
               }}}
  end

  test "renders not found error when actor is deleted", %{conn: conn} do
    account = Fixtures.Accounts.create_account()

    actor =
      Fixtures.Actors.create_actor(type: :account_admin_user, account: account)
      |> Fixtures.Actors.delete()

    identity = Fixtures.Auth.create_identity(account: account, actor: actor)

    assert_raise Web.LiveErrors.NotFoundError, fn ->
      conn
      |> authorize_conn(identity)
      |> live(~p"/#{account}/actors/#{actor}")
    end
  end

  test "renders breadcrumbs item", %{conn: conn} do
    account = Fixtures.Accounts.create_account()
    actor = Fixtures.Actors.create_actor(type: :account_admin_user, account: account)
    identity = Fixtures.Auth.create_identity(account: account, actor: actor)

    {:ok, _lv, html} =
      conn
      |> authorize_conn(identity)
      |> live(~p"/#{account}/actors/#{actor}")

    assert item = Floki.find(html, "[aria-label='Breadcrumb']")
    breadcrumbs = String.trim(Floki.text(item))
    assert breadcrumbs =~ "Actors"
    assert breadcrumbs =~ actor.name
  end

  describe "users" do
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

    test "renders actor details", %{
      account: account,
      actor: actor,
      identity: identity,
      conn: conn
    } do
      group = Fixtures.Actors.create_group(account: account)
      Fixtures.Actors.create_membership(account: account, actor: actor, group: group)

      {:ok, lv, html} =
        conn
        |> authorize_conn(identity)
        |> live(~p"/#{account}/actors/#{actor}")

      assert html =~ "User"

      table =
        lv
        |> element("#actor")
        |> render()
        |> vertical_table_to_map()

      assert table["groups"] == group.name
      assert table["name"] == actor.name
      assert table["role"] == "admin"
      assert around_now?(table["last signed in"])
    end

    test "renders actor identities", %{
      account: account,
      actor: actor,
      identity: admin_identity,
      conn: conn
    } do
      invited_identity =
        Fixtures.Auth.create_identity(account: account, actor: actor)
        |> Ecto.Changeset.change(
          created_by: :identity,
          created_by_identity_id: admin_identity.id
        )
        |> Repo.update!()

      synced_identity =
        Fixtures.Auth.create_identity(account: account, actor: actor)
        |> Ecto.Changeset.change(created_by: :provider)
        |> Repo.update!()

      admin_identity = Repo.preload(admin_identity, :provider)
      invited_identity = Repo.preload(invited_identity, :provider)
      synced_identity = Repo.preload(synced_identity, :provider)

      {:ok, lv, _html} =
        conn
        |> authorize_conn(admin_identity)
        |> live(~p"/#{account}/actors/#{actor}")

      lv
      |> element("#actors")
      |> render()
      |> table_to_map()
      |> with_table_row(
        "identity",
        "#{admin_identity.provider.name} #{admin_identity.provider_identifier}",
        fn row ->
          assert row["actions"] == "Delete"
          assert around_now?(row["last signed in"])
          assert around_now?(row["created"])
        end
      )
      |> with_table_row(
        "identity",
        "#{invited_identity.provider.name} #{invited_identity.provider_identifier}",
        fn row ->
          assert row["actions"] == "Delete"
          assert row["created"] =~ "by #{actor.name}"
          assert row["last signed in"] == "never"
        end
      )
      |> with_table_row(
        "identity",
        "#{synced_identity.provider.name} #{synced_identity.provider_identifier}",
        fn row ->
          refute row["actions"]
          assert row["created"] =~ "synced"
          assert row["created"] =~ "from #{synced_identity.provider.name}"
          assert row["last signed in"] == "never"
        end
      )
    end

    test "allows deleting identities", %{
      account: account,
      actor: actor,
      identity: admin_identity,
      conn: conn
    } do
      other_identity =
        Fixtures.Auth.create_identity(account: account, actor: actor)
        |> Ecto.Changeset.change(
          created_by: :identity,
          created_by_identity_id: admin_identity.id
        )
        |> Repo.update!()

      {:ok, lv, _html} =
        conn
        |> authorize_conn(admin_identity)
        |> live(~p"/#{account}/actors/#{actor}")

      assert lv
             |> element("#identity-#{other_identity.id} button", "Delete")
             |> render_click()
             |> Floki.find(".flash-info")
             |> element_to_text() =~ "Identity was deleted."
    end

    test "allows creating identities", %{
      account: account,
      actor: actor,
      identity: identity,
      conn: conn
    } do
      {:ok, lv, _html} =
        conn
        |> authorize_conn(identity)
        |> live(~p"/#{account}/actors/#{actor}")

      lv
      |> element("a", "Create Identity")
      |> render_click()

      assert_redirect(lv, ~p"/#{account}/actors/users/#{actor}/new_identity")

      actor = Fixtures.Actors.update(actor, last_synced_at: DateTime.utc_now())

      {:ok, lv, _html} =
        conn
        |> authorize_conn(identity)
        |> live(~p"/#{account}/actors/#{actor}")

      lv
      |> element("a", "Create Identity")
      |> render_click()

      assert_redirect(lv, ~p"/#{account}/actors/users/#{actor}/new_identity")
    end

    test "allows editing actors", %{
      account: account,
      actor: actor,
      identity: identity,
      conn: conn
    } do
      {:ok, lv, _html} =
        conn
        |> authorize_conn(identity)
        |> live(~p"/#{account}/actors/#{actor}")

      assert lv
             |> element("a", "Edit User")
             |> render_click() ==
               {:error,
                {:live_redirect, %{to: ~p"/#{account}/actors/#{actor}/edit", kind: :push}}}
    end

    test "allows deleting actors", %{
      account: account,
      identity: identity,
      conn: conn
    } do
      actor = Fixtures.Actors.create_actor(type: :account_admin_user, account: account)

      {:ok, lv, _html} =
        conn
        |> authorize_conn(identity)
        |> live(~p"/#{account}/actors/#{actor}")

      lv
      |> element("button", "Delete User")
      |> render_click()

      assert_redirect(lv, ~p"/#{account}/actors")

      assert Repo.get(Domain.Actors.Actor, actor.id).deleted_at
    end

    test "renders error when trying to delete last admin", %{
      account: account,
      actor: actor,
      identity: identity,
      conn: conn
    } do
      {:ok, lv, _html} =
        conn
        |> authorize_conn(identity)
        |> live(~p"/#{account}/actors/#{actor}")

      assert lv
             |> element("button", "Delete User")
             |> render_click()
             |> Floki.find(".flash-error")
             |> element_to_text() =~ "You can't delete the last admin of an account."

      refute Repo.get(Domain.Actors.Actor, actor.id).deleted_at
    end

    test "allows disabling actors", %{
      account: account,
      identity: identity,
      conn: conn
    } do
      actor = Fixtures.Actors.create_actor(type: :account_admin_user, account: account)

      {:ok, lv, _html} =
        conn
        |> authorize_conn(identity)
        |> live(~p"/#{account}/actors/#{actor}")

      refute has_element?(lv, "button", "Enable User")

      assert lv
             |> element("button", "Disable User")
             |> render_click()
             |> Floki.find(".flash-info")
             |> element_to_text() =~ "Actor was disabled."

      assert Repo.get(Domain.Actors.Actor, actor.id).disabled_at
    end

    test "renders error when trying to disable last admin", %{
      account: account,
      actor: actor,
      identity: identity,
      conn: conn
    } do
      {:ok, lv, _html} =
        conn
        |> authorize_conn(identity)
        |> live(~p"/#{account}/actors/#{actor}")

      assert lv
             |> element("button", "Disable User")
             |> render_click()
             |> Floki.find(".flash-error")
             |> element_to_text() =~ "You can't disable the last admin of an account."

      refute Repo.get(Domain.Actors.Actor, actor.id).disabled_at
    end

    test "allows enabling actors", %{
      account: account,
      identity: identity,
      conn: conn
    } do
      actor = Fixtures.Actors.create_actor(type: :account_admin_user, account: account)
      actor = Fixtures.Actors.disable(actor)

      {:ok, lv, _html} =
        conn
        |> authorize_conn(identity)
        |> live(~p"/#{account}/actors/#{actor}")

      refute has_element?(lv, "button", "Disable User")

      assert lv
             |> element("button", "Enable User")
             |> render_click()
             |> Floki.find(".flash-info")
             |> element_to_text() =~ "Actor was enabled."

      refute Repo.get(Domain.Actors.Actor, actor.id).disabled_at
    end
  end

  describe "service accounts" do
    setup do
      account = Fixtures.Accounts.create_account()
      actor = Fixtures.Actors.create_actor(type: :service_account, account: account)

      identity =
        Fixtures.Auth.create_identity(
          actor: [type: :account_admin_user],
          account: account
        )

      %{
        account: account,
        actor: actor,
        identity: identity
      }
    end

    test "renders actor details", %{
      account: account,
      actor: actor,
      identity: identity,
      conn: conn
    } do
      group = Fixtures.Actors.create_group(account: account)
      Fixtures.Actors.create_membership(account: account, actor: actor, group: group)

      {:ok, lv, html} =
        conn
        |> authorize_conn(identity)
        |> live(~p"/#{account}/actors/#{actor}")

      assert html =~ "Service Account"

      assert lv
             |> element("#actor")
             |> render()
             |> vertical_table_to_map() == %{
               "groups" => group.name,
               "last signed in" => "never",
               "name" => actor.name,
               "role" => "service account"
             }
    end

    test "renders actor identities", %{
      account: account,
      actor: actor,
      identity: admin_identity,
      conn: conn
    } do
      identity = Fixtures.Auth.create_identity(account: account, actor: actor)
      identity = Repo.preload(identity, :provider)

      {:ok, lv, _html} =
        conn
        |> authorize_conn(admin_identity)
        |> live(~p"/#{account}/actors/#{actor}")

      lv
      |> element("#actors")
      |> render()
      |> table_to_map()
      |> with_table_row(
        "identity",
        "#{identity.provider.name} #{identity.provider_identifier}",
        fn row ->
          assert row["actions"] == "Delete"
          assert around_now?(row["created"])
          assert row["last signed in"] == "never"
        end
      )
    end

    test "allows deleting identities", %{
      account: account,
      actor: actor,
      identity: admin_identity,
      conn: conn
    } do
      other_identity =
        Fixtures.Auth.create_identity(account: account, actor: actor)
        |> Ecto.Changeset.change(
          created_by: :identity,
          created_by_identity_id: admin_identity.id
        )
        |> Repo.update!()

      {:ok, lv, _html} =
        conn
        |> authorize_conn(admin_identity)
        |> live(~p"/#{account}/actors/#{actor}")

      assert lv
             |> element("#identity-#{other_identity.id} button", "Delete")
             |> render_click()
             |> Floki.find(".flash-info")
             |> element_to_text() =~ "Identity was deleted."
    end

    test "allows creating identities", %{
      account: account,
      actor: actor,
      identity: identity,
      conn: conn
    } do
      {:ok, lv, _html} =
        conn
        |> authorize_conn(identity)
        |> live(~p"/#{account}/actors/#{actor}")

      lv
      |> element("a:first-child", "Create Token")
      |> render_click()

      assert_redirect(lv, ~p"/#{account}/actors/service_accounts/#{actor}/new_identity")
    end

    test "allows editing actors", %{
      account: account,
      actor: actor,
      identity: identity,
      conn: conn
    } do
      {:ok, lv, _html} =
        conn
        |> authorize_conn(identity)
        |> live(~p"/#{account}/actors/#{actor}")

      assert lv
             |> element("a", "Edit Service Account")
             |> render_click() ==
               {:error,
                {:live_redirect, %{to: ~p"/#{account}/actors/#{actor}/edit", kind: :push}}}
    end

    test "allows deleting actors", %{
      account: account,
      identity: identity,
      actor: actor,
      conn: conn
    } do
      {:ok, lv, _html} =
        conn
        |> authorize_conn(identity)
        |> live(~p"/#{account}/actors/#{actor}")

      lv
      |> element("button", "Delete Service Account")
      |> render_click()

      assert_redirect(lv, ~p"/#{account}/actors")

      assert Repo.get(Domain.Actors.Actor, actor.id).deleted_at
    end

    test "allows disabling actors", %{
      account: account,
      actor: actor,
      identity: identity,
      conn: conn
    } do
      {:ok, lv, _html} =
        conn
        |> authorize_conn(identity)
        |> live(~p"/#{account}/actors/#{actor}")

      refute has_element?(lv, "button", "Enable Service Account")

      assert lv
             |> element("button", "Disable Service Account")
             |> render_click()
             |> Floki.find(".flash-info")
             |> element_to_text() =~ "Actor was disabled."

      assert Repo.get(Domain.Actors.Actor, actor.id).disabled_at
    end

    test "allows enabling actors", %{
      account: account,
      actor: actor,
      identity: identity,
      conn: conn
    } do
      actor = Fixtures.Actors.disable(actor)

      {:ok, lv, _html} =
        conn
        |> authorize_conn(identity)
        |> live(~p"/#{account}/actors/#{actor}")

      refute has_element?(lv, "button", "Disable Service Account")

      assert lv
             |> element("button", "Enable Service Account")
             |> render_click()
             |> Floki.find(".flash-info")
             |> element_to_text() =~ "Actor was enabled."

      refute Repo.get(Domain.Actors.Actor, actor.id).disabled_at
    end
  end
end
