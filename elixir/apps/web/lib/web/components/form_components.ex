defmodule Web.FormComponents do
  @moduledoc """
  Provides Form UI components.
  """
  use Phoenix.Component
  use Web, :verified_routes
  import Web.CoreComponents, only: [icon: 1, error: 1, label: 1, translate_error: 1]

  ### Inputs ###

  @doc """
  Renders an input with label and error messages.

  A `%Phoenix.HTML.Form{}` and field name may be passed to the input
  to build input names and error messages, or all the attributes and
  errors may be passed explicitly.

  ## Examples

      <.input field={@form[:email]} type="email" />
      <.input name="my-input" errors={["oh no!"]} />
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :value_id, :any,
    default: nil,
    doc: "the function for generating the value from the list of schemas for select inputs"

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file hidden month number password
               range radio search select tel text textarea taglist time url week)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox and radio inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"

  attr :rest, :global,
    include: ~w(autocomplete cols disabled form list max maxlength min minlength
                pattern placeholder readonly required rows size step)

  slot :inner_block

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(field.errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn ->
      if assigns.value_id do
        Enum.map(field.value, fn
          %Ecto.Changeset{} = value ->
            value
            |> Ecto.Changeset.apply_changes()
            |> assigns.value_id.()

          value ->
            assigns.value_id.(value)
        end)
      else
        field.value
      end
    end)
    |> input()
  end

  def input(%{type: "radio"} = assigns) do
    ~H"""
    <div phx-feedback-for={@name}>
      <label class="flex items-center gap-2 text-gray-900 dark:text-gray-300">
        <input type="radio" id={@id} name={@name} value={@value} checked={@checked} class={~w[
          w-4 h-4 border-gray-300 focus:ring-2 focus:ring-primary-300
          dark:focus:ring-primary-600 dark:focus:bg-primary-600
          dark:bg-gray-700 dark:border-gray-600]} {@rest} />
        <%= @label %>
      </label>
    </div>
    """
  end

  def input(%{type: "checkbox", value: value} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn -> Phoenix.HTML.Form.normalize_value("checkbox", value) end)

    ~H"""
    <div phx-feedback-for={@name}>
      <label class="flex items-center gap-4 text-sm leading-6 text-zinc-600">
        <input type="hidden" name={@name} value="false" />
        <input
          type="checkbox"
          id={@id}
          name={@name}
          value="true"
          checked={@checked}
          class="rounded border-zinc-300 text-zinc-900 focus:ring-0"
          {@rest}
        />
        <%= @label %>
      </label>
      <.error :for={msg <- @errors} data-validation-error-for={@name}><%= msg %></.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div phx-feedback-for={@name}>
      <.label for={@id}><%= @label %></.label>
      <select id={@id} name={@name} class={~w[
          bg-gray-50 border border-gray-300 text-gray-900 text-sm rounded-lg focus:ring-blue-500
          focus:border-blue-500 block w-full p-2.5 dark:bg-gray-700 dark:border-gray-600
          dark:placeholder-gray-400 dark:text-white dark:focus:ring-blue-500 dark:focus:border-blue-500
        ]} multiple={@multiple} {@rest}>
        <option :if={@prompt} value=""><%= @prompt %></option>
        <%= Phoenix.HTML.Form.options_for_select(@options, @value) %>
      </select>
      <.error :for={msg <- @errors} data-validation-error-for={@name}><%= msg %></.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div phx-feedback-for={@name}>
      <.label for={@id}><%= @label %></.label>
      <textarea
        id={@id}
        name={@name}
        class={[
          "mt-2 block w-full rounded-lg text-zinc-900 focus:ring-0 sm:text-sm sm:leading-6",
          "phx-no-feedback:border-zinc-300 phx-no-feedback:focus:border-zinc-400",
          "min-h-[6rem] border-zinc-300 focus:border-zinc-400",
          @errors != [] && "border-rose-400 focus:border-rose-400"
        ]}
        {@rest}
      ><%= Phoenix.HTML.Form.normalize_value("textarea", @value) %></textarea>
      <.error :for={msg <- @errors} data-validation-error-for={@name}><%= msg %></.error>
    </div>
    """
  end

  def input(%{type: "taglist"} = assigns) do
    values =
      if is_nil(assigns.value),
        do: [],
        else: Enum.map(assigns.value, &Phoenix.HTML.Form.normalize_value("text", &1))

    assigns = assign(assigns, :values, values)

    ~H"""
    <div phx-feedback-for={@name}>
      <.label for={@id}><%= @label %></.label>

      <div :for={{value, index} <- Enum.with_index(@values)} class="flex mt-2">
        <input
          type="text"
          name={"#{@name}[]"}
          id={@id}
          value={value}
          class={[
            "bg-gray-50 p-2.5 block w-full rounded-lg border text-gray-900 focus:ring-primary-600 text-sm",
            "phx-no-feedback:border-gray-300 phx-no-feedback:focus:border-primary-600",
            "disabled:bg-slate-50 disabled:text-slate-500 disabled:border-slate-200 disabled:shadow-none",
            "border-gray-300 focus:border-primary-600",
            @errors != [] && "border-rose-400 focus:border-rose-400"
          ]}
          {@rest}
        />
        <.button
          type="button"
          phx-click={"delete:#{@name}"}
          phx-value-index={index}
          class="align-middle ml-2 inline-block whitespace-nowrap"
        >
          <.icon name="hero-minus" /> Delete
        </.button>
      </div>

      <.button type="button" phx-click={"add:#{@name}"} class="mt-2">
        <.icon name="hero-plus" /> Add
      </.button>

      <.error :for={msg <- @errors} data-validation-error-for={@name}><%= msg %></.error>
    </div>
    """
  end

  def input(%{type: "hidden"} = assigns) do
    ~H"""
    <input
      type={@type}
      name={@name}
      id={@id}
      value={Phoenix.HTML.Form.normalize_value(@type, @value)}
      {@rest}
    />
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    ~H"""
    <div phx-feedback-for={@name}>
      <.label :if={not is_nil(@label)} for={@id}><%= @label %></.label>
      <input
        type={@type}
        name={@name}
        id={@id}
        value={Phoenix.HTML.Form.normalize_value(@type, @value)}
        class={[
          "bg-gray-50 p-2.5 block w-full rounded-lg border text-gray-900 focus:ring-primary-600 text-sm",
          "phx-no-feedback:border-gray-300 phx-no-feedback:focus:border-primary-600",
          "disabled:bg-slate-50 disabled:text-slate-500 disabled:border-slate-200 disabled:shadow-none",
          "border-gray-300 focus:border-primary-600",
          @errors != [] && "border-rose-400 focus:border-rose-400"
        ]}
        {@rest}
      />
      <.error :for={msg <- @errors} data-validation-error-for={@name}><%= msg %></.error>
    </div>
    """
  end

  ### Buttons ###

  @doc """
  Render a button group.
  """
  slot :first, required: true, doc: "First button"
  slot :middle, required: false, doc: "Middle button(s)"
  slot :last, required: true, doc: "Last button"

  def button_group(assigns) do
    ~H"""
    <div class="inline-flex rounded-md shadow-sm" role="group">
      <button type="button" class={~w[
          px-4 py-2 text-sm font-medium text-gray-900 bg-white border border-gray-200
          rounded-l-lg hover:bg-gray-100 hover:text-blue-700 focus:z-10 focus:ring-2
          focus:ring-blue-700 focus:text-blue-700 dark:bg-gray-700 dark:border-gray-600
          dark:text-white dark:hover:text-white dark:hover:bg-gray-600
          dark:focus:ring-blue-500 dark:focus:text-white
        ]}>
        <%= render_slot(@first) %>
      </button>
      <%= for middle <- @middle do %>
        <button type="button" class={~w[
            px-4 py-2 text-sm font-medium text-gray-900 bg-white border-t border-b
            border-gray-200 hover:bg-gray-100 hover:text-blue-700 focus:z-10 focus:ring-2
            focus:ring-blue-700 focus:text-blue-700 dark:bg-gray-700 dark:border-gray-600
            dark:text-white dark:hover:text-white dark:hover:bg-gray-600 dark:focus:ring-blue-500
            dark:focus:text-white
          ]}>
          <%= render_slot(middle) %>
        </button>
      <% end %>
      <button type="button" class={~w[
          px-4 py-2 text-sm font-medium text-gray-900 bg-white border border-gray-200
          rounded-r-lg hover:bg-gray-100 hover:text-blue-700 focus:z-10 focus:ring-2
          focus:ring-blue-700 focus:text-blue-700 dark:bg-gray-700 dark:border-gray-600
          dark:text-white dark:hover:text-white dark:hover:bg-gray-600 dark:focus:ring-blue-500
          dark:focus:text-white
        ]}>
        <%= render_slot(@last) %>
      </button>
    </div>
    """
  end

  @doc """
  Base button type to be used directly or by the specialized button types above. e.g. edit_button, delete_button, etc.

  If a navigate path is provided, an <a> tag will be used, otherwise a <button> tag will be used.

  ## Examples

      <.button style="primary" navigate={~p"/actors/new"} icon="hero-plus">
        Add user
      </.button>

      <.button>Send!</.button>
      <.button phx-click="go" class="ml-2">Send!</.button>
  """
  attr :navigate, :string,
    required: false,
    doc: """
    The path to navigate to, when set an <a> tag will be used,
    otherwise a <button> tag will be used
    """

  attr :class, :string, default: "", doc: "Custom classes to be added to the button"
  attr :style, :string, default: nil, doc: "The style of the button"
  attr :type, :string, default: nil, doc: "The button type"

  attr :icon, :string,
    default: nil,
    required: false,
    doc: "The icon to be displayed on the button"

  attr :rest, :global, include: ~w(disabled form name value navigate)
  slot :inner_block, required: true, doc: "The label for the button"

  def button(%{navigate: _} = assigns) do
    ~H"""
    <.link class={button_style(@style) ++ [@class]} navigate={@navigate} {@rest}>
      <.icon :if={@icon} name={@icon} class="h-3.5 w-3.5 mr-2" />
      <%= render_slot(@inner_block) %>
    </.link>
    """
  end

  def button(assigns) do
    ~H"""
    <button type={@type} class={button_style(@style) ++ [@class]} {@rest}>
      <.icon :if={@icon} name={@icon} class="h-3.5 w-3.5 mr-2" />
      <%= render_slot(@inner_block) %>
    </button>
    """
  end

  @doc """
  Render a submit button.

  ## Examples

    <.submit_button>
      Save
    </.submit_button>
  """

  attr :rest, :global
  slot :inner_block, required: true

  def submit_button(assigns) do
    ~H"""
    <.button style="primary" {@rest}>
      <%= render_slot(@inner_block) %>
    </.button>
    """
  end

  @doc """
  Render a delete button.

  ## Examples

    <.delete_button path={Routes.user_path(@conn, :edit, @user.id)}/>
      Edit user
    </.delete_button>
  """
  slot :inner_block, required: true
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  def delete_button(assigns) do
    ~H"""
    <.button style="danger" icon="hero-trash-solid" {@rest}>
      <%= render_slot(@inner_block) %>
    </.button>
    """
  end

  @doc """
  Renders an add button.

  ## Examples

    <.add_button navigate={~p"/actors/new"}>
      Add user
    </.add_button>
  """
  attr :navigate, :any, required: true, doc: "Path to navigate to"
  attr :class, :string, default: ""
  slot :inner_block, required: true

  def add_button(assigns) do
    ~H"""
    <.button style="primary" navigate={@navigate} icon="hero-plus">
      <%= render_slot(@inner_block) %>
    </.button>
    """
  end

  @doc """
  Renders an edit button.

  ## Examples

    <.edit_button path={Routes.user_path(@conn, :edit, @user.id)}/>
      Edit user
    </.edit_button>
  """
  attr :navigate, :any, required: true, doc: "Path to navigate to"
  slot :inner_block, required: true

  def edit_button(assigns) do
    ~H"""
    <.button style="primary" navigate={@navigate} icon="hero-pencil-solid">
      <%= render_slot(@inner_block) %>
    </.button>
    """
  end

  defp button_style do
    [
      "flex items-center justify-center",
      "px-4 py-2 rounded-lg",
      "font-medium text-sm",
      "focus:ring-4 focus:outline-none",
      "phx-submit-loading:opacity-75"
    ]
  end

  defp button_style("danger") do
    button_style() ++
      [
        "text-red-600",
        "border border-red-600",
        "hover:text-white hover:bg-red-600 focus:ring-red-300",
        "dark:border-red-500 dark:text-red-500 dark:hover:text-white dark:hover:bg-red-600 dark:focus:ring-red-900"
      ]
  end

  defp button_style(_style) do
    button_style() ++
      [
        "text-white",
        "bg-primary-500",
        "hover:bg-primary-600",
        "focus:ring-primary-300",
        "dark:bg-primary-600 dark:hover:bg-primary-700 dark:focus:ring-primary-800"
      ]
  end

  ### Forms ###

  @doc """
  Renders a simple form.

  ## Examples

      <.simple_form for={@form} phx-change="validate" phx-submit="save">
        <.input field={@form[:email]} label="Email"/>
        <.input field={@form[:username]} label="Username" />
        <:actions>
          <.button>Save</.button>
        </:actions>
      </.simple_form>
  """
  attr :for, :any, required: true, doc: "the datastructure for the form"
  attr :as, :any, default: nil, doc: "the server side parameter to collect all input under"

  attr :rest, :global,
    include: ~w(autocomplete name rel action enctype method novalidate target),
    doc: "the arbitrary HTML attributes to apply to the form tag"

  slot :inner_block, required: true
  slot :actions, doc: "the slot for form actions, such as a submit button"

  def simple_form(assigns) do
    ~H"""
    <.form :let={f} for={@for} as={@as} {@rest}>
      <div class="space-y-8 bg-white">
        <%= render_slot(@inner_block, f) %>
        <div :for={action <- @actions} class="mt-2 flex items-center justify-between gap-6">
          <%= render_slot(action, f) %>
        </div>
      </div>
    </.form>
    """
  end
end
