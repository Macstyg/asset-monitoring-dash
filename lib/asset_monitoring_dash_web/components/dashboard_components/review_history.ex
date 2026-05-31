defmodule AssetMonitoringDashWeb.DashboardComponents.ReviewHistory do
  @moduledoc """
  Asset-scoped audit trail for operator workflow decisions.
  """

  use Phoenix.Component

  alias AssetMonitoringDashWeb.UI.Badge
  alias AssetMonitoringDashWeb.UI.Card

  attr :decisions, :list, required: true

  def render(assigns) do
    ~H"""
    <Card.surface id="review-history" variant={:inset} class="mt-2 w-full">
      <div class="flex items-start justify-between gap-4">
        <div>
          <h3 class="text-sm font-semibold text-app-fg">Review history</h3>
          <p class="mt-1 text-xs leading-5 text-app-muted">
            Operator decisions and system resets for this position.
          </p>
        </div>
        <span
          id="review-history-count"
          class="rounded-full bg-app-bg px-2.5 py-1 font-mono text-xs font-semibold text-app-muted ring-1 ring-app-border"
        >
          {length(@decisions)}
        </span>
      </div>

      <div id="review-history-list" class="mt-4 space-y-3">
        <div
          :if={@decisions == []}
          id="review-history-empty"
          class="rounded-app border border-dashed border-app-border bg-app-bg px-3 py-4 text-sm text-app-muted"
        >
          No operator decisions recorded yet.
        </div>

        <article
          :for={decision <- @decisions}
          id={"review-history-#{decision.id}"}
          class="rounded-app border border-app-border bg-app-bg px-3 py-3"
        >
          <div class="flex flex-wrap items-center justify-between gap-2">
            <div class="flex min-w-0 items-center gap-2">
              <Badge.render label={decision.state_label} tone={decision.state_tone} />
              <span class="font-mono text-xs text-app-muted">
                by {decision.actor}
              </span>
            </div>
            <time class="font-mono text-xs text-app-muted">
              {format_time(decision.occurred_at)}
            </time>
          </div>

          <p class="mt-3 text-sm font-semibold text-app-fg">
            {decision.audit.reason}
          </p>
          <p
            :if={decision.audit.note != ""}
            class="mt-1 text-xs leading-5 text-app-muted"
          >
            {decision.audit.note}
          </p>
        </article>
      </div>
    </Card.surface>
    """
  end

  defp format_time(%DateTime{} = occurred_at), do: Calendar.strftime(occurred_at, "%H:%M:%S UTC")
  defp format_time(_occurred_at), do: "pending"
end
