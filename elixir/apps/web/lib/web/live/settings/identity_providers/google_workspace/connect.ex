defmodule Web.Settings.IdentityProviders.GoogleWorkspace.Connect do
  @doc """
  This controller is similar to Web.AuthController, but it is used to connect IdP account
  to the actor and provider rather than logging in using it.
  """
  use Web, :controller
  alias Domain.Auth.Adapters.GoogleWorkspace

  def redirect_to_idp(conn, %{"provider_id" => provider_id}) do
    account = conn.assigns.account

    with {:ok, provider} <- Domain.Auth.fetch_provider_by_id(provider_id) do
      redirect_url =
        url(
          ~p"/#{account}/settings/identity_providers/google_workspace/#{provider}/handle_callback"
        )

      Web.AuthController.redirect_to_idp(conn, redirect_url, provider)
    else
      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Provider does not exist.")
        |> redirect(to: ~p"/#{account}/settings/identity_providers")
    end
  end

  def handle_idp_callback(conn, %{
        "provider_id" => provider_id,
        "state" => state,
        "code" => code
      }) do
    account = conn.assigns.account
    subject = conn.assigns.subject

    with {:ok, code_verifier, conn} <-
           Web.AuthController.verify_state_and_fetch_verifier(conn, provider_id, state) do
      payload = {
        url(
          ~p"/#{account}/settings/identity_providers/google_workspace/#{provider_id}/handle_callback"
        ),
        code_verifier,
        code
      }

      with {:ok, provider} <- Domain.Auth.fetch_provider_by_id(provider_id),
           {:ok, identity} <-
             GoogleWorkspace.verify_and_upsert_identity(subject.actor, provider, payload),
           attrs = %{
             adapter_state: identity.provider_state,
             disabled_at: nil
           },
           {:ok, _provider} <- Domain.Auth.update_provider(provider, attrs, subject) do
        redirect(conn,
          to: ~p"/#{account}/settings/identity_providers/google_workspace/#{provider_id}"
        )
      else
        {:error, :expired_token} ->
          conn
          |> put_flash(:error, "The provider returned an expired token, please try again.")
          |> redirect(
            to: ~p"/#{account}/settings/identity_providers/google_workspace/#{provider_id}"
          )

        {:error, :invalid_token} ->
          conn
          |> put_flash(:error, "The provider returned an invalid token, please try again.")
          |> redirect(
            to: ~p"/#{account}/settings/identity_providers/google_workspace/#{provider_id}"
          )

        {:error, :not_found} ->
          conn
          |> put_flash(:error, "Provider does not exist.")
          |> redirect(
            to: ~p"/#{account}/settings/identity_providers/google_workspace/#{provider_id}"
          )

        {:error, %Ecto.Changeset{} = changeset} ->
          errors =
            changeset
            |> Ecto.Changeset.traverse_errors(fn {message, opts} ->
              Regex.replace(~r"%{(\w+)}", message, fn _, key ->
                opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
              end)
            end)
            |> Map.get(:adapter_config, %{})

          conn
          |> put_flash(
            :error,
            {:validation_errors, "There is an error with provider behaviour", errors}
          )
          |> redirect(
            to: ~p"/#{account}/settings/identity_providers/google_workspace/#{provider_id}"
          )

        {:error, _reason} ->
          conn
          |> put_flash(:error, "You may not authenticate to this account.")
          |> redirect(
            to: ~p"/#{account}/settings/identity_providers/google_workspace/#{provider_id}"
          )
      end
    else
      {:error, :invalid_state, conn} ->
        conn
        |> put_flash(:error, "Your session has expired, please try again.")
        |> redirect(
          to: ~p"/#{account}/settings/identity_providers/google_workspace/#{provider_id}"
        )
    end
  end
end
