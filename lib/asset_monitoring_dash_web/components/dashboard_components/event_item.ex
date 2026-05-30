defmodule AssetMonitoringDashWeb.DashboardComponents.EventItem do
  @moduledoc """
  Compact event row for the operational activity feed.
  """

  use Phoenix.Component

  alias AssetMonitoringDashWeb.UI.Badge

  attr :chain, :string, required: true
  attr :actor, :string, required: true
  attr :detail, :string, required: true
  attr :id, :string, required: true
  attr :severity_label, :string, required: true

  attr :severity_tone, :atom,
    values: [:neutral, :success, :info, :warning, :danger],
    default: :neutral

  attr :source_label, :string, required: true

  attr :source_tone, :atom,
    values: [:neutral, :success, :info, :warning, :danger],
    default: :neutral

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
        <div class="mt-2 flex flex-wrap items-center gap-1.5">
          <Badge.render label={@source_label} tone={@source_tone} />
          <Badge.render label={@severity_label} tone={@severity_tone} />
          <span class="font-mono text-xs text-app-muted">by {@actor}</span>
        </div>
      </div>

      <Badge.render label={@status} tone={@tone} />
    </article>
    """
  end
end
