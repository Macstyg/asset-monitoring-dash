defmodule AssetMonitoringDashWeb.UI.Card do
  @moduledoc """
  Card primitives for metric, context, and framed content surfaces.
  """

  use Phoenix.Component

  attr :class, :string, default: ""
  attr :hover, :boolean, default: false
  attr :padding, :string, default: "p-5"
  attr :rest, :global

  slot :inner_block, required: true

  def surface(assigns) do
    ~H"""
    <section
      class={[
        card_surface_class(@hover),
        @padding,
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </section>
    """
  end

  attr :class, :string, default: ""
  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :context, :string, default: nil
  attr :delta, :string, required: true
  attr :delta_tone, :atom, required: true
  attr :description, :string, default: nil
  attr :rest, :global

  def render(assigns) do
    ~H"""
    <article
      id={@id}
      class={[
        card_surface_class(true),
        "group min-h-32 px-5 py-4",
        @class
      ]}
      {@rest}
    >
      <div class="flex min-w-0 items-center justify-between gap-4">
        <p class="min-w-0 truncate font-mono text-xs font-semibold uppercase tracking-[0.14em] text-app-muted">
          {@label}
        </p>
        <p
          :if={@context}
          class="shrink-0 font-mono text-xs font-semibold uppercase tracking-[0.14em] text-app-muted"
        >
          {@context}
        </p>
      </div>

      <p class="mt-5 truncate font-display text-4xl font-bold leading-none tracking-normal text-app-fg md:text-5xl">
        {@value}
      </p>

      <div class={[
        "mt-5 flex min-w-0 items-center gap-2 font-mono text-sm font-semibold leading-5",
        signal_class(@delta_tone)
      ]}>
        <span aria-hidden="true">{signal_marker(@delta_tone)}</span>
        <p class="truncate">
          {@delta}<span :if={@description}>{@description}</span>
        </p>
      </div>
    </article>
    """
  end

  defp card_surface_class(true) do
    card_surface_class(false) <>
      " transition duration-200 hover:-translate-y-0.5 hover:border-app-accent-2 hover:bg-app-surface-2"
  end

  defp card_surface_class(false) do
    "min-w-0 rounded-app border border-app-border bg-app-surface shadow-app-panel"
  end

  defp signal_class(:positive), do: "text-app-accent"
  defp signal_class(:negative), do: "text-app-danger"
  defp signal_class(:warning), do: "text-app-warn"
  defp signal_class(:neutral), do: "text-app-muted"

  defp signal_marker(:positive), do: "▲"
  defp signal_marker(:negative), do: "▼"
  defp signal_marker(:warning), do: "▲"
  defp signal_marker(:neutral), do: "•"
end
