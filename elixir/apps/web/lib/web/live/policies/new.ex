defmodule Web.Policies.New do
  use Web, :live_view
  alias Domain.{Resources, Actors, Policies}

  def mount(_params, _session, socket) do
    with {:ok, resources} <- Resources.list_resources(socket.assigns.subject),
         {:ok, actor_groups} <- Actors.list_groups(socket.assigns.subject) do
      form = to_form(Policies.new_policy(%{}, socket.assigns.subject))

      socket =
        assign(socket,
          resources: resources,
          actor_groups: actor_groups,
          page_title: "Add Policy",
          form: form
        )

      {:ok, socket, temporary_assigns: [form: %Phoenix.HTML.Form{}]}
    else
      _other -> raise Web.LiveErrors.NotFoundError
    end
  end

  def render(assigns) do
    ~H"""
    <.breadcrumbs account={@account}>
      <.breadcrumb path={~p"/#{@account}/policies"}>Policies</.breadcrumb>
      <.breadcrumb path={~p"/#{@account}/policies/new"}><%= @page_title %></.breadcrumb>
    </.breadcrumbs>
    <.section>
      <:title>
        <%= @page_title %>
      </:title>
      <:content>
        <div class="max-w-2xl px-4 py-8 mx-auto lg:py-16">
          <h2 class="mb-4 text-xl font-bold text-gray-900 dark:text-white">Policy details</h2>
          <.simple_form for={@form} phx-submit="submit" phx-change="validate">
            <.base_error form={@form} field={:base} />
            <.input
              field={@form[:actor_group_id]}
              label="Group"
              type="select"
              options={Enum.map(@actor_groups, fn g -> [key: g.name, value: g.id] end)}
              value={@form[:actor_group_id].value}
              required
            />
            <.input
              field={@form[:resource_id]}
              label="Resource"
              type="select"
              options={Enum.map(@resources, fn r -> [key: r.name, value: r.id] end)}
              value={@form[:resource_id].value}
              required
            />
            <.input
              field={@form[:description]}
              type="textarea"
              label="Description"
              placeholder="Enter a reason for creating a policy here"
              phx-debounce="300"
            />
            <:actions>
              <.button phx-disable-with="Creating Policy..." class="w-full">
                Create Policy
              </.button>
            </:actions>
          </.simple_form>
        </div>
      </:content>
    </.section>
    """
  end

  def handle_event("validate", %{"policy" => policy_params}, socket) do
    form =
      Policies.new_policy(policy_params, socket.assigns.subject)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, form: form)}
  end

  def handle_event("submit", %{"policy" => policy_params}, socket) do
    with {:ok, policy} <- Policies.create_policy(policy_params, socket.assigns.subject) do
      {:noreply, redirect(socket, to: ~p"/#{socket.assigns.account}/policies/#{policy}")}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        form = to_form(changeset)
        {:noreply, assign(socket, form: form)}
    end
  end
end
