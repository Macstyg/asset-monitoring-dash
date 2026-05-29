defmodule AssetMonitoringDashWeb.UI.FilterBar do
  @moduledoc """
  Responsive filter form primitive with search and select controls.
  """

  use Phoenix.Component

  import AssetMonitoringDashWeb.CoreComponents, only: [icon: 1]

  alias AssetMonitoringDashWeb.UI.ChainIcon
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
      class={["space-y-3", @class]}
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
    <div class="relative">
      <.icon
        name="hero-magnifying-glass"
        class="pointer-events-none absolute left-3.5 top-1/2 size-4 -translate-y-1/2 text-app-muted"
      />
      <input
        id={@field.id}
        name={@field.name}
        type="search"
        value={Form.normalize_value("search", @field.value)}
        placeholder={@placeholder}
        class={[
          "min-h-11 w-full rounded-app border border-app-border bg-app-surface px-10 text-sm text-app-fg outline-none transition placeholder:text-app-muted focus:border-app-accent/50 focus:ring-2 focus:ring-app-accent/15",
          @class
        ]}
        {@rest}
      />
    </div>
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

  attr :field, Phoenix.HTML.FormField, required: true
  attr :icon, :string, default: "hero-adjustments-horizontal"
  attr :label, :string, required: true
  attr :options, :list, required: true
  attr :open, :boolean, default: false
  attr :search_field, Phoenix.HTML.FormField, required: true
  attr :search_placeholder, :string, default: "Find option"

  def multi_select(assigns) do
    assigns =
      assigns
      |> assign(:selected_values, selected_values(assigns.field.value))
      |> assign(:visible_values, Enum.map(assigns.options, &option_value/1))

    ~H"""
    <details
      id={"#{@field.id}_filter"}
      class="group relative"
      open={@open}
    >
      <summary
        id={"#{@field.id}_toggle"}
        class="flex h-11 cursor-pointer list-none items-center gap-2 rounded-app border border-app-border bg-app-surface px-3 text-sm font-semibold text-app-fg transition hover:border-app-accent/40 hover:bg-app-surface-2/70 [&::-webkit-details-marker]:hidden"
      >
        <.icon name={@icon} class="size-4 text-app-muted" />
        <span>{@label}</span>
        <span
          :if={length(@selected_values) > 0}
          class="rounded-full bg-app-accent/10 px-2 py-0.5 font-mono text-xs text-app-accent ring-1 ring-app-accent/20"
        >
          {length(@selected_values)}
        </span>
        <.icon
          name="hero-chevron-down"
          class="ml-auto size-4 text-app-muted transition group-open:rotate-180"
        />
      </summary>

      <div
        id={"#{@field.id}_panel"}
        class="absolute left-0 z-30 mt-2 w-72 rounded-app border border-app-border bg-app-surface p-2 shadow-app-panel"
      >
        <div class="relative">
          <.icon
            name="hero-magnifying-glass"
            class="pointer-events-none absolute left-3 top-1/2 size-4 -translate-y-1/2 text-app-muted"
          />
          <input
            id={@search_field.id}
            name={@search_field.name}
            type="search"
            value={Form.normalize_value("search", @search_field.value)}
            placeholder={@search_placeholder}
            phx-debounce="200"
            class="h-10 w-full rounded-app border border-app-border bg-app-bg px-9 text-sm text-app-fg outline-none transition placeholder:text-app-muted focus:border-app-accent/60 focus:ring-2 focus:ring-app-accent/15"
          />
        </div>

        <input type="hidden" name={"#{@field.name}[]"} value="" />
        <input
          :for={value <- hidden_selected_values(@selected_values, @visible_values)}
          type="hidden"
          name={"#{@field.name}[]"}
          value={value}
        />

        <div class="mt-2 max-h-64 overflow-y-auto pr-1">
          <label
            :for={option <- @options}
            id={option_id(@field, option_value(option))}
            class="flex cursor-pointer items-center gap-3 rounded-app px-2 py-2 text-sm text-app-fg transition hover:bg-app-surface-2"
          >
            <input
              type="checkbox"
              name={"#{@field.name}[]"}
              value={option_value(option)}
              checked={option_value(option) in @selected_values}
              class="size-4 shrink-0 rounded border-app-border bg-app-bg accent-[var(--amd-accent)]"
            />
            <.option_icon option={option} />
            <span class="min-w-0 flex-1 truncate">{option_label(option)}</span>
          </label>

          <div
            :if={@options == []}
            class="px-2 py-6 text-center text-sm text-app-muted"
          >
            No matches
          </div>
        </div>
      </div>
    </details>
    """
  end

  attr :option, :map, required: true

  defp option_icon(%{option: %{icon: :chain}} = assigns) do
    ~H"""
    <ChainIcon.render chain={option_label(@option)} class="size-6 text-[0.55rem]" />
    """
  end

  defp option_icon(assigns) do
    ~H"""
    <span class={[
      "grid size-6 shrink-0 place-items-center rounded-full font-mono text-[0.62rem] font-bold ring-1 ring-inset",
      option_tone_class(Map.get(@option, :tone, :neutral))
    ]}>
      {Map.get(@option, :icon_text, option_initial(@option))}
    </span>
    """
  end

  defp selected_values(nil), do: []
  defp selected_values(values) when is_list(values), do: Enum.reject(values, &(&1 in [nil, ""]))
  defp selected_values(""), do: []
  defp selected_values(value), do: [value]

  defp hidden_selected_values(selected_values, visible_values) do
    Enum.reject(selected_values, &(&1 in visible_values))
  end

  defp option_label(%{label: label}), do: label
  defp option_value(%{value: value}), do: value
  defp option_initial(%{label: label}), do: label |> String.first() |> String.upcase()

  defp option_id(field, value) do
    "#{field.id}_#{value}"
    |> String.replace(~r/[^A-Za-z0-9_-]/, "-")
  end

  defp option_tone_class(:success), do: "bg-app-accent/10 text-app-accent ring-app-accent/20"
  defp option_tone_class(:info), do: "bg-app-accent-2/10 text-app-accent-2 ring-app-accent-2/20"
  defp option_tone_class(:warning), do: "bg-app-warn/10 text-app-warn ring-app-warn/25"
  defp option_tone_class(:danger), do: "bg-app-danger/10 text-app-danger ring-app-danger/25"
  defp option_tone_class(:neutral), do: "bg-app-surface-2 text-app-muted ring-app-border"
end
