defmodule AssetMonitoringDashWeb.DashboardLive do
  use AssetMonitoringDashWeb, :live_view

  alias AssetMonitoringDash.DemoData
  alias AssetMonitoringDashWeb.Formatters
  alias AssetMonitoringDashWeb.UI.AssetIdentity
  alias AssetMonitoringDashWeb.UI.Card
  alias AssetMonitoringDashWeb.UI.RiskBadge
  alias AssetMonitoringDashWeb.UI.Table

  @impl true
  def mount(_params, _session, socket) do
    snapshot = DemoData.portfolio_snapshot()

    socket =
      socket
      |> assign(:page_title, "Asset Risk Cockpit")
      |> assign(:snapshot, snapshot)
      |> assign(:metric_cards, metric_cards(snapshot))
      |> assign(:assets, DemoData.monitored_assets())

    {:ok, socket}
  end

  defp metric_cards(snapshot) do
    [
      %{
        id: "collateral-value-card",
        label: "Collateral value",
        context: "24H",
        value: Formatters.compact_usd(snapshot.total_collateral_value_usd),
        delta: Formatters.signed_percent(snapshot.collateral_delta_percent),
        delta_tone: :positive,
        description: "collateral inflow"
      },
      %{
        id: "active-loans-card",
        label: "Active loans",
        context: "OPEN",
        value: Integer.to_string(snapshot.active_loans),
        delta: "+#{snapshot.active_loans_delta} today",
        delta_tone: :neutral,
        description: "borrow positions"
      },
      %{
        id: "weighted-apy-card",
        label: "Weighted APY",
        context: "BLENDED",
        value: Formatters.ltv(snapshot.weighted_apy_percent),
        delta: Formatters.signed_percent(snapshot.apy_delta_percent),
        delta_tone: :negative,
        description: "since last rebalance"
      },
      %{
        id: "risk-score-card",
        label: "Risk score",
        context: "HEALTH < 1.2",
        value: "#{snapshot.risk_score}/100",
        delta: "+#{snapshot.risk_delta} risk",
        delta_tone: :warning,
        description: "#{String.downcase(snapshot.risk_band)} pressure"
      }
    ]
  end
end
