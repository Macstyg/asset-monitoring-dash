defmodule AssetMonitoringDashWeb.UI.FilterBar do
  @moduledoc """
  Responsive filter form primitive with search and select controls.
  """

  use Phoenix.Component

  alias Phoenix.HTML.Form

  attr :class, :string, default: ""
  attr :form, :any, required: true
  attr :id, :string, required: true
  attr :rest, :global

  slot :inner_block, required: true

  def render(assigns) do
    ~H"""
    <.form
      for={@form}
      id={@id}
      class={[
        "grid gap-3 lg:grid-cols-[minmax(240px,1fr)_180px_180px]",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </.form>
    """
  end

  attr :class, :string, default: ""
  attr :field, Phoenix.HTML.FormField, required: true
  attr :placeholder, :string, default: nil
  attr :rest, :global, include: ~w(autocomplete)

  def search(assigns) do
    ~H"""
    <input
      id={@field.id}
      name={@field.name}
      type="search"
      value={Form.normalize_value("search", @field.value)}
      placeholder={@placeholder}
      class={[
        "min-h-11 w-full rounded-app border border-app-border bg-app-surface px-4 text-sm text-app-fg outline-none transition placeholder:text-app-muted focus:border-app-accent/50 focus:ring-2 focus:ring-app-accent/15",
        @class
      ]}
      {@rest}
    />
    """
  end

  attr :class, :string, default: ""
  attr :field, Phoenix.HTML.FormField, required: true
  attr :options, :list, required: true
  attr :rest, :global

  def select(assigns) do
    ~H"""
    <div class="relative">
      <select
        id={@field.id}
        name={@field.name}
        class={[
          "h-11 w-full appearance-none rounded-app border border-app-border bg-app-surface px-3 pr-10 text-sm font-semibold text-app-fg outline-none transition focus:border-app-accent/50 focus:ring-2 focus:ring-app-accent/15",
          @class
        ]}
        {@rest}
      >
        {Form.options_for_select(@options, @field.value)}
      </select>
      <span
        aria-hidden="true"
        class="pointer-events-none absolute right-3.5 top-1/2 size-2.5 -translate-y-2/3 rotate-45 border-b-2 border-r-2 border-app-fg"
      >
      </span>
    </div>
    """
  end
end
