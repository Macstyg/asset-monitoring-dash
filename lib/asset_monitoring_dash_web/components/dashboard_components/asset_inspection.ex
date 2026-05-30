defmodule AssetMonitoringDashWeb.DashboardComponents.AssetInspection do
  @moduledoc """
  Inspection panel for the currently selected collateral asset.
  """

  use Phoenix.Component

  alias AssetMonitoringDashWeb.DashboardComponents.AssetTrend
  alias AssetMonitoringDashWeb.DashboardComponents.ReviewWorkflowPanel
  alias AssetMonitoringDashWeb.DashboardComponents.RiskBadge
  alias AssetMonitoringDashWeb.Formatters
  alias AssetMonitoringDashWeb.UI.Card
  alias AssetMonitoringDashWeb.UI.EntityIdentity

  attr :asset, :map, required: true
  attr :health_factor, :string, required: true
  attr :ltv_trend, :list, required: true
  attr :risk_recommendation, :map, required: true
  attr :risk_explanation, :map, required: true
  attr :review_state, :map, required: true

  slot :actions

  def render(assigns) do
    ~H"""
    <Card.surface id="asset-inspection">
      <div class="flex items-start justify-between gap-4">
        <div>
          <h2 class="text-base font-semibold text-app-fg">Asset inspection</h2>
          <p class="mt-1 text-sm text-app-muted">Collateral position detail and review signals.</p>
        </div>
        <RiskBadge.render label={@asset.risk_band} />
      </div>

      <div :if={@actions != []} class="mt-4 flex flex-wrap gap-2">
        {render_slot(@actions)}
      </div>

      <EntityIdentity.render
        class="mt-5"
        name={@asset.name}
        caption={"#{@asset.chain} / #{@asset.ecosystem}"}
        asset_icon={@asset.icon}
      />

      <dl class="mt-5 grid grid-cols-2 gap-3">
        <div class="rounded-app border border-app-border bg-app-surface-2 p-3">
          <dt class="font-mono text-xs uppercase tracking-[0.12em] text-app-muted">Value</dt>
          <dd class="mt-2 font-mono text-sm font-semibold tabular-nums text-app-fg">
            {Formatters.usd(@asset.current_value_usd)}
          </dd>
        </div>
        <div class="rounded-app border border-app-border bg-app-surface-2 p-3">
          <dt class="font-mono text-xs uppercase tracking-[0.12em] text-app-muted">Loan</dt>
          <dd class="mt-2 font-mono text-sm font-semibold tabular-nums text-app-fg">
            {Formatters.usd(@asset.loan_value_usd)}
          </dd>
        </div>
        <div class="rounded-app border border-app-border bg-app-surface-2 p-3">
          <dt class="font-mono text-xs uppercase tracking-[0.12em] text-app-muted">LTV</dt>
          <dd class="mt-2 font-mono text-sm font-semibold tabular-nums text-app-fg">
            {Formatters.ltv(@asset.ltv_percent)}
          </dd>
        </div>
        <div class="rounded-app border border-app-border bg-app-surface-2 p-3">
          <dt class="font-mono text-xs uppercase tracking-[0.12em] text-app-muted">Health</dt>
          <dd class="mt-2 font-mono text-sm font-semibold tabular-nums text-app-fg">
            {@health_factor}
          </dd>
        </div>
        <div class="rounded-app border border-app-border bg-app-surface-2 p-3">
          <dt class="font-mono text-xs uppercase tracking-[0.12em] text-app-muted">Oracle</dt>
          <dd class="mt-2 flex flex-wrap items-center gap-2">
            <span class={[
              "rounded-full px-2 py-0.5 font-mono text-xs font-semibold ring-1 ring-inset",
              oracle_class(@asset.oracle_status)
            ]}>
              {@asset.oracle_status}
            </span>
            <span class="font-mono text-xs text-app-muted">
              {Formatters.duration_seconds(@asset.oracle_freshness_seconds)} ago
            </span>
          </dd>
        </div>
        <div class="rounded-app border border-app-border bg-app-surface-2 p-3">
          <dt class="font-mono text-xs uppercase tracking-[0.12em] text-app-muted">Liquidity</dt>
          <dd class="mt-2 flex flex-wrap items-center gap-2">
            <span class={[
              "rounded-full px-2 py-0.5 font-mono text-xs font-semibold ring-1 ring-inset",
              liquidity_class(@asset.liquidity_status)
            ]}>
              {@asset.liquidity_status}
            </span>
            <span class="font-mono text-xs text-app-muted">
              {Formatters.usd(@asset.market_depth_usd)} depth
            </span>
          </dd>
        </div>
      </dl>

      <div class="mt-4 rounded-app border border-app-border bg-app-surface-2 p-3">
        <div class="flex items-center justify-between gap-3">
          <span class="font-mono text-xs uppercase tracking-[0.12em] text-app-muted">Risk score</span>
          <span class="font-mono text-sm font-semibold tabular-nums text-app-fg">
            {@asset.risk_score}/100
          </span>
        </div>
        <div class="mt-3 h-2 overflow-hidden rounded-full bg-app-bg">
          <div
            class="h-full rounded-full bg-linear-to-r from-app-accent via-app-warn to-app-danger"
            style={"width: #{@asset.risk_score}%"}
          >
          </div>
        </div>
      </div>

      <ReviewWorkflowPanel.render
        recommendation={@risk_recommendation}
        review_state={@review_state}
      />

      <AssetTrend.render points={@ltv_trend} />

      <div
        id="risk-explanation"
        class="mt-4 rounded-app border border-app-border bg-app-surface-2 p-3"
      >
        <p class="font-mono text-xs uppercase tracking-[0.12em] text-app-muted">Risk drivers</p>
        <p id="risk-explanation-headline" class="mt-2 text-sm font-semibold text-app-fg">
          {@risk_explanation.headline}
        </p>

        <div class="mt-3 space-y-3">
          <div
            :for={reason <- @risk_explanation.reasons}
            id={"risk-reason-#{reason.id}"}
            class="flex items-start justify-between gap-3 border-t border-app-border pt-3 first:border-t-0 first:pt-0"
          >
            <div class="min-w-0">
              <p class="text-sm font-semibold text-app-fg">{reason.label}</p>
              <p class="mt-1 text-xs leading-5 text-app-muted">{reason.detail}</p>
            </div>
            <span class={[
              "shrink-0 rounded-full px-2.5 py-1 font-mono text-xs font-semibold tabular-nums ring-1 ring-inset",
              reason_class(reason.tone)
            ]}>
              {format_reason_metric(reason.metric)}
            </span>
          </div>
        </div>
      </div>
    </Card.surface>
    """
  end

  defp format_reason_metric({:decimal, value}), do: Formatters.decimal(value)
  defp format_reason_metric({:percent, value}), do: Formatters.ltv(value)
  defp format_reason_metric({:usd, value}), do: Formatters.usd(value)

  defp reason_class(:danger), do: "bg-app-danger/10 text-app-danger ring-app-danger/25"
  defp reason_class(:warning), do: "bg-app-warn/10 text-app-warn ring-app-warn/25"
  defp reason_class(:success), do: "bg-app-accent/10 text-app-accent ring-app-accent/20"
  defp reason_class(:neutral), do: "bg-app-bg text-app-muted ring-app-border"

  defp oracle_class("Fresh"), do: "bg-app-accent/10 text-app-accent ring-app-accent/20"
  defp oracle_class("Delayed"), do: "bg-app-warn/10 text-app-warn ring-app-warn/25"
  defp oracle_class("Stale"), do: "bg-app-danger/10 text-app-danger ring-app-danger/25"
  defp oracle_class(_status), do: "bg-app-bg text-app-muted ring-app-border"

  defp liquidity_class("Deep"), do: "bg-app-accent/10 text-app-accent ring-app-accent/20"
  defp liquidity_class("Thin"), do: "bg-app-warn/10 text-app-warn ring-app-warn/25"
  defp liquidity_class("Illiquid"), do: "bg-app-danger/10 text-app-danger ring-app-danger/25"
  defp liquidity_class(_status), do: "bg-app-bg text-app-muted ring-app-border"
end
