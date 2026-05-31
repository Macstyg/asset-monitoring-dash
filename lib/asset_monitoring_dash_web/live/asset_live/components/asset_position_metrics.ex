defmodule AssetMonitoringDashWeb.AssetLive.Components.AssetPositionMetrics do
  @moduledoc """
  Identity, valuation, and signal metrics for the inspected asset.
  """

  use Phoenix.Component

  import AssetMonitoringDashWeb.CoreComponents, only: [icon: 1]

  alias AssetMonitoringDashWeb.Formatters
  alias AssetMonitoringDashWeb.UI.Card
  alias AssetMonitoringDashWeb.UI.EntityIdentity
  alias AssetMonitoringDashWeb.UI.Tooltip

  attr :asset, :map, required: true
  attr :health_factor, :string, required: true

  def render(assigns) do
    ~H"""
    <EntityIdentity.render
      class="mt-5"
      name={@asset.name}
      caption={"#{@asset.chain} / #{@asset.ecosystem}"}
      asset_icon={@asset.icon}
    />

    <dl class="mt-5 grid grid-cols-2 gap-3">
      <Card.surface tag="div" variant={:inset}>
        <dt class="font-mono text-xs uppercase tracking-[0.12em] text-app-muted">Value</dt>
        <dd class="mt-2 font-mono text-sm font-semibold tabular-nums text-app-fg">
          {Formatters.usd(@asset.current_value_usd)}
        </dd>
      </Card.surface>
      <Card.surface tag="div" variant={:inset}>
        <dt class="font-mono text-xs uppercase tracking-[0.12em] text-app-muted">Loan</dt>
        <dd class="mt-2 font-mono text-sm font-semibold tabular-nums text-app-fg">
          {Formatters.usd(@asset.loan_value_usd)}
        </dd>
      </Card.surface>
      <Card.surface tag="div" variant={:inset}>
        <dt class="flex items-center gap-1.5 font-mono text-xs uppercase tracking-[0.12em] text-app-muted">
          LTV
          <Tooltip.render
            id="asset-ltv-tooltip"
            tip="Loan-to-value: borrowed amount divided by current collateral value."
            trigger_label="Explain LTV"
          >
            <.icon name="hero-question-mark-circle" class="size-3.5" />
          </Tooltip.render>
        </dt>
        <dd class="mt-2 font-mono text-sm font-semibold tabular-nums text-app-fg">
          {Formatters.ltv(@asset.ltv_percent)}
        </dd>
      </Card.surface>
      <Card.surface tag="div" variant={:inset}>
        <dt class="flex items-center gap-1.5 font-mono text-xs uppercase tracking-[0.12em] text-app-muted">
          Health
          <Tooltip.render
            id="asset-health-tooltip"
            tip="Health factor estimates collateral safety. Lower values mean less buffer before liquidation pressure."
            trigger_label="Explain health factor"
          >
            <.icon name="hero-question-mark-circle" class="size-3.5" />
          </Tooltip.render>
        </dt>
        <dd class="mt-2 font-mono text-sm font-semibold tabular-nums text-app-fg">
          {@health_factor}
        </dd>
      </Card.surface>
      <Card.surface tag="div" variant={:inset}>
        <dt class="flex items-center gap-1.5 font-mono text-xs uppercase tracking-[0.12em] text-app-muted">
          Oracle
          <Tooltip.render
            id="asset-oracle-tooltip"
            tip="Oracle freshness shows how recently the external price feed confirmed this asset value."
            trigger_label="Explain oracle freshness"
          >
            <.icon name="hero-question-mark-circle" class="size-3.5" />
          </Tooltip.render>
        </dt>
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
      </Card.surface>
      <Card.surface tag="div" variant={:inset}>
        <dt class="flex items-center gap-1.5 font-mono text-xs uppercase tracking-[0.12em] text-app-muted">
          Liquidity
          <Tooltip.render
            id="asset-liquidity-tooltip"
            tip="Liquidity describes how much market depth is available to exit or liquidate the collateral."
            trigger_label="Explain liquidity"
          >
            <.icon name="hero-question-mark-circle" class="size-3.5" />
          </Tooltip.render>
        </dt>
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
      </Card.surface>
    </dl>
    """
  end

  defp oracle_class("Fresh"), do: "bg-app-accent/10 text-app-accent ring-app-accent/20"
  defp oracle_class("Delayed"), do: "bg-app-warn/10 text-app-warn ring-app-warn/25"
  defp oracle_class("Stale"), do: "bg-app-danger/10 text-app-danger ring-app-danger/25"
  defp oracle_class(_status), do: "bg-app-bg text-app-muted ring-app-border"

  defp liquidity_class("Deep"), do: "bg-app-accent/10 text-app-accent ring-app-accent/20"
  defp liquidity_class("Thin"), do: "bg-app-warn/10 text-app-warn ring-app-warn/25"
  defp liquidity_class("Illiquid"), do: "bg-app-danger/10 text-app-danger ring-app-danger/25"
  defp liquidity_class(_status), do: "bg-app-bg text-app-muted ring-app-border"
end
