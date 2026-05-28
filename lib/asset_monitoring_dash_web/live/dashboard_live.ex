defmodule AssetMonitoringDashWeb.DashboardLive do
  use AssetMonitoringDashWeb, :live_view

  alias AssetMonitoringDash.DemoData
  alias AssetMonitoringDashWeb.UI.Card

  @impl true
  def mount(_params, _session, socket) do
    snapshot = DemoData.portfolio_snapshot()

    socket =
      socket
      |> assign(:page_title, "Asset Risk Cockpit")
      |> assign(:snapshot, snapshot)
      |> assign(:metric_cards, metric_cards(snapshot))

    {:ok, socket}
  end

  defp metric_cards(snapshot) do
    [
      %{
        id: "collateral-value-card",
        label: "Collateral value",
        context: "24H",
        value: format_currency(snapshot.total_collateral_value_usd),
        delta: format_signed_percent(snapshot.collateral_delta_percent),
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
        value: "#{format_decimal(snapshot.weighted_apy_percent)}%",
        delta: format_signed_percent(snapshot.apy_delta_percent),
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

  defp format_currency(value) when is_integer(value) do
    "$#{format_decimal(value / 1_000_000)}M"
  end

  defp format_signed_percent(value) when value > 0, do: "+#{format_decimal(value)}%"
  defp format_signed_percent(value), do: "#{format_decimal(value)}%"

  defp format_decimal(value) do
    :erlang.float_to_binary(value / 1, decimals: 1)
  end
end
