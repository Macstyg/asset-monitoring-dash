defmodule AssetMonitoringDashWeb.UI.Card do
  @moduledoc """
  Compact dashboard metric card.
  """

  use Phoenix.Component

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
        "group min-h-32 min-w-0 rounded-app border border-app-border bg-app-surface px-5 py-4 shadow-app-panel transition duration-200 hover:-translate-y-0.5 hover:border-app-accent-2 hover:bg-app-surface-2",
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
          {@delta}<span :if={@description}> {@description}</span>
        </p>
      </div>
    </article>
    """
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
