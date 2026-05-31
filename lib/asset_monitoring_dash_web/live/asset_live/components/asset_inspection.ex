defmodule AssetMonitoringDashWeb.AssetLive.Components.AssetInspection do
  @moduledoc """
  Inspection panel for the currently selected collateral asset.
  """

  use Phoenix.Component

  alias AssetMonitoringDashWeb.AssetLive.Components.AssetPositionMetrics
  alias AssetMonitoringDashWeb.AssetLive.Components.AssetTrend
  alias AssetMonitoringDashWeb.AssetLive.Components.ReviewWorkflowPanel
  alias AssetMonitoringDashWeb.AssetLive.Components.RiskDrivers
  alias AssetMonitoringDashWeb.AssetLive.Components.RiskScorePanel
  alias AssetMonitoringDashWeb.SharedComponents.RiskBadge
  alias AssetMonitoringDashWeb.UI.Card

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

      <AssetPositionMetrics.render asset={@asset} health_factor={@health_factor} />

      <RiskScorePanel.render score={@asset.risk_score} />

      <ReviewWorkflowPanel.render
        recommendation={@risk_recommendation}
        review_state={@review_state}
      />

      <AssetTrend.render points={@ltv_trend} />

      <RiskDrivers.render risk_explanation={@risk_explanation} />
    </Card.surface>
    """
  end
end
