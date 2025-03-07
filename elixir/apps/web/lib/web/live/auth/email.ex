defmodule Web.Auth.Email do
  use Web, {:live_view, layout: {Web.Layouts, :public}}

  def mount(
        %{
          "account_id_or_slug" => account_id_or_slug,
          "provider_id" => provider_id,
          "provider_identifier" => provider_identifier
        } = params,
        session,
        socket
      ) do
    form = to_form(%{"secret" => nil})

    query_params = Map.take(params, ["client_platform", "client_csrf_token"])
    session_params = Map.take(session, ["client_platform", "client_csrf_token"])
    params = Map.merge(session_params, query_params)

    {:ok, socket,
     temporary_assigns: [
       form: form,
       provider_identifier: provider_identifier,
       account_id_or_slug: account_id_or_slug,
       provider_id: provider_id,
       resent: params["resent"],
       redirect_params: params,
       client_platform: params["client_platform"],
       client_csrf_token: params["client_csrf_token"]
     ]}
  end

  def render(assigns) do
    ~H"""
    <section class="bg-gray-50 dark:bg-gray-900">
      <div class="flex flex-col items-center justify-center px-6 py-8 mx-auto md:h-screen lg:py-0">
        <.logo />

        <div class="w-full col-span-6 mx-auto bg-white rounded-lg shadow dark:bg-gray-800 md:mt-0 sm:max-w-lg xl:p-0">
          <div class="p-6 space-y-4 lg:space-y-6 sm:p-8">
            <h1 class="text-xl font-bold leading-tight tracking-tight text-gray-900 sm:text-2xl dark:text-white">
              Please check your email
            </h1>
            <.flash flash={@flash} kind={:error} phx-click={JS.hide(transition: "fade-out")} />
            <.flash flash={@flash} kind={:info} phx-click={JS.hide(transition: "fade-out")} />

            <div :if={is_nil(@client_platform)}>
              <p>
                Should the provided email be registered, a sign-in link will be dispatched to your email account.
                Please click this link to proceed with your login.
              </p>
              <.resend
                account_id_or_slug={@account_id_or_slug}
                provider_id={@provider_id}
                provider_identifier={@provider_identifier}
                client_platform={@client_platform}
                client_csrf_token={@client_csrf_token}
              />
              <div class="flex">
                <.dev_email_provider_link url="https://mail.google.com/mail/" name="Gmail" />
                <.email_provider_link url="https://mail.google.com/mail/" name="Gmail" />
                <.email_provider_link url="https://outlook.live.com/mail/" name="Outlook" />
              </div>
            </div>
            <div :if={not is_nil(@client_platform)}>
              <p>
                Should the provided email be registered, a sign-in token will be dispatched to your email account.
                Please copy and paste this token into the form below to proceed with your login.
              </p>

              <form
                id="verify-sign-in-token"
                action={
                  ~p"/#{@account_id_or_slug}/sign_in/providers/#{@provider_id}/verify_sign_in_token"
                }
                method="get"
                class="my-4 flex"
              >
                <.input type="hidden" name="identity_id" value={@provider_identifier} />

                <input
                  type="text"
                  name="secret"
                  id="secret"
                  class={[
                    "block p-2.5 w-full text-sm",
                    "bg-gray-50 text-gray-900",
                    "rounded-l-lg border-gray-300 focus:border-primary-600 focus:ring-primary-600"
                  ]}
                  required
                  placeholder="Enter token from email"
                />

                <button
                  type="submit"
                  class={[
                    "block p-2.5",
                    "text-sm text-white font-medium",
                    "items-center text-center",
                    "bg-primary-700 rounded-r-lg",
                    "focus:ring-4 focus:ring-primary-200 hover:bg-primary-800"
                  ]}
                >
                  Submit
                </button>
              </form>
              <.resend
                account_id_or_slug={@account_id_or_slug}
                provider_id={@provider_id}
                provider_identifier={@provider_identifier}
                client_platform={@client_platform}
                client_csrf_token={@client_csrf_token}
              /> or
              <.link
                navigate={~p"/#{@account_id_or_slug}?#{@redirect_params}"}
                class="font-medium text-blue-600 dark:text-blue-500 hover:underline"
              >
                use a different Sign In method
              </.link>
              .
            </div>
          </div>
        </div>
      </div>
    </section>
    """
  end

  def handle_info(:hide_resent_flash, socket) do
    {:noreply, assign(socket, :resent, nil)}
  end

  if Mix.env() in [:dev, :test] do
    defp dev_email_provider_link(assigns) do
      ~H"""
      <.email_provider_link url={~p"/dev/mailbox"} name="Local" />
      """
    end
  else
    defp dev_email_provider_link(assigns), do: ~H""
  end

  defp resend(assigns) do
    ~H"""
    <.form
      for={%{}}
      id="resend-email"
      as={:email}
      class="inline"
      action={
        ~p"/#{@account_id_or_slug}/sign_in/providers/#{@provider_id}/request_magic_link?resend=true"
      }
      method="post"
    >
      <.input type="hidden" name="email[provider_identifier]" value={@provider_identifier} />
      <.input
        :if={not is_nil(@client_platform)}
        type="hidden"
        name="client_platform"
        value={@client_platform}
      />
      <.input
        :if={not is_nil(@client_csrf_token)}
        type="hidden"
        name="client_csrf_token"
        value={@client_csrf_token}
      />
      <span>
        Did not receive it?
        <button
          type="submit"
          class="inline font-medium text-blue-600 dark:text-blue-500 hover:underline"
        >
          Resend email
        </button>
      </span>
    </.form>
    """
  end

  defp email_provider_link(assigns) do
    ~H"""
    <a
      href={@url}
      class={[
        "w-1/2 m-2 inline-flex items-center justify-center py-2.5 px-5",
        "text-sm font-medium text-gray-900 bg-white ",
        "rounded-lg border border-gray-200",
        "focus:outline-none focus:z-10 focus:ring-4 focus:ring-gray-200",
        "hover:text-gray-900 hover:bg-gray-100"
      ]}
    >
      Open <%= @name %>
    </a>
    """
  end
end
