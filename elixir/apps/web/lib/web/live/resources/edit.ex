defmodule Web.Resources.Edit do
  use Web, :live_view
  import Web.Resources.Components
  alias Domain.Gateways
  alias Domain.Resources

  def mount(%{"id" => id}, _session, socket) do
    with {:ok, resource} <-
           Resources.fetch_resource_by_id(id, socket.assigns.subject, preload: :gateway_groups),
         {:ok, gateway_groups} <- Gateways.list_groups(socket.assigns.subject) do
      form = Resources.change_resource(resource, socket.assigns.subject) |> to_form()

      {:ok, assign(socket, resource: resource, gateway_groups: gateway_groups, form: form),
       temporary_assigns: [
         form: %Phoenix.HTML.Form{}
       ]}
    else
      _other -> raise Web.LiveErrors.NotFoundError
    end
  end

  def render(assigns) do
    ~H"""
    <.breadcrumbs account={@account}>
      <.breadcrumb path={~p"/#{@account}/resources"}>Resources</.breadcrumb>
      <.breadcrumb path={~p"/#{@account}/resources/#{@resource.id}"}>
        <%= @resource.name %>
      </.breadcrumb>
      <.breadcrumb path={~p"/#{@account}/resources/#{@resource.id}/edit"}>
        Edit
      </.breadcrumb>
    </.breadcrumbs>
    <.section>
      <:title>
        Edit Resource
      </:title>
      <:content>
        <div class="max-w-2xl px-4 py-8 mx-auto lg:py-16">
          <h2 class="mb-4 text-xl font-bold text-gray-900 dark:text-white">Edit Resource details</h2>

          <.form for={@form} phx-change={:change} phx-submit={:submit} class="space-y-4 lg:space-y-6">
            <.input
              field={@form[:name]}
              type="text"
              label="Name"
              placeholder="Name this resource"
              required
            />

            <.filters_form form={@form[:filters]} />

            <.connections_form
              form={@form[:connections]}
              account={@account}
              resource={@resource}
              gateway_groups={@gateway_groups}
            />

            <.submit_button phx-disable-with="Updating Resource...">
              Save
            </.submit_button>
          </.form>
        </div>
      </:content>
    </.section>
    """
  end

  def handle_event("change", %{"resource" => attrs}, socket) do
    attrs =
      attrs
      |> map_filters_form_attrs()
      |> map_connections_form_attrs()

    changeset =
      Resources.change_resource(socket.assigns.resource, attrs, socket.assigns.subject)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  def handle_event("submit", %{"resource" => attrs}, socket) do
    attrs =
      attrs
      |> map_filters_form_attrs()
      |> map_connections_form_attrs()

    case Resources.update_resource(socket.assigns.resource, attrs, socket.assigns.subject) do
      {:ok, resource} ->
        {:noreply,
         push_navigate(socket, to: ~p"/#{socket.assigns.account}/resources/#{resource.id}")}

      {:error, changeset} ->
        changeset = Map.put(changeset, :action, :validate)
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end
