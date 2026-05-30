defmodule AssetMonitoringDashWeb.DashboardComponents.AssetSummary do
  @moduledoc """
  Filter-aware asset portfolio summary for the dashboard.
  """

  use Phoenix.Component

  alias AssetMonitoringDashWeb.Formatters
  alias AssetMonitoringDashWeb.UI.Card

  attr :summary, :map, required: true

  def render(assigns) do
    ~H"""
    <Card.surface
      id="asset-summary"
      aria-label="Visible asset subset summary"
      variant={:subtle}
      class="mt-5"
    >
      <div class="flex min-w-0 flex-col gap-3 lg:flex-row lg:items-center lg:justify-between">
        <div class="min-w-0">
          <p class="font-mono text-xs uppercase tracking-[0.12em] text-app-muted">
            Visible subset
          </p>
          <p class="mt-1 text-sm text-app-muted">
            Recalculated from the currently filtered table rows.
          </p>
        </div>

        <dl class="grid min-w-0 gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <div class="min-w-0">
            <dt class="text-xs font-medium text-app-muted">Rows</dt>
            <dd
              id="asset-summary-visible-count"
              class="mt-1 font-mono text-sm font-semibold tabular-nums text-app-fg"
            >
              {@summary.visible_count}
            </dd>
          </div>

          <div class="min-w-0">
            <dt class="text-xs font-medium text-app-muted">Subset value</dt>
            <dd
              id="asset-summary-value"
              class="mt-1 font-mono text-sm font-semibold tabular-nums text-app-fg"
            >
              {Formatters.usd(@summary.total_value_usd)}
            </dd>
          </div>

          <div class="min-w-0">
            <dt class="text-xs font-medium text-app-muted">Elevated+</dt>
            <dd
              id="asset-summary-at-risk"
              class="mt-1 font-mono text-sm font-semibold tabular-nums text-app-fg"
            >
              {@summary.at_risk_count}
            </dd>
          </div>

          <div class="min-w-0">
            <dt class="text-xs font-medium text-app-muted">Highest LTV</dt>
            <dd
              id="asset-summary-highest-ltv"
              class="mt-1 font-mono text-sm font-semibold tabular-nums text-app-fg"
            >
              {Formatters.ltv(@summary.highest_ltv_percent)}
            </dd>
          </div>
        </dl>
      </div>
    </Card.surface>
    """
  end
end
