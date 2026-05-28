defmodule AssetMonitoringDashWeb.UI.EventItem do
  @moduledoc """
  Compact event row for the operational activity feed.
  """

  use Phoenix.Component

  attr :chain, :string, required: true
  attr :detail, :string, required: true
  attr :id, :string, required: true
  attr :status, :string, required: true
  attr :time_label, :string, required: true
  attr :title, :string, required: true
  attr :tone, :atom, values: [:neutral, :success, :warning, :danger], default: :neutral

  def render(assigns) do
    ~H"""
    <article
      id={@id}
      class="grid gap-3 border-t border-app-border py-3 first:border-t-0 first:pt-0 sm:grid-cols-[72px_minmax(0,1fr)_auto] sm:items-center"
    >
      <time class="font-mono text-xs text-app-muted">{@time_label}</time>

      <div class="min-w-0">
        <div class="flex min-w-0 flex-wrap items-center gap-x-2 gap-y-1">
          <p class="truncate text-sm font-semibold text-app-fg">{@title}</p>
          <span class="font-mono text-xs text-app-muted">{@chain}</span>
        </div>
        <p class="mt-1 text-sm leading-5 text-app-muted">{@detail}</p>
      </div>

      <span class={[
        "w-fit rounded-full px-2.5 py-1 font-mono text-xs font-semibold ring-1 ring-inset",
        tone_class(@tone)
      ]}>
        {@status}
      </span>
    </article>
    """
  end

  defp tone_class(:success), do: "bg-app-accent/10 text-app-accent ring-app-accent/20"
  defp tone_class(:warning), do: "bg-app-warn/10 text-app-warn ring-app-warn/25"
  defp tone_class(:danger), do: "bg-app-danger/10 text-app-danger ring-app-danger/25"
  defp tone_class(:neutral), do: "bg-app-surface-2 text-app-muted ring-app-border"
end
