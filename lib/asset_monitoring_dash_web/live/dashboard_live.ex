defmodule AssetMonitoringDashWeb.DashboardLive do
  use AssetMonitoringDashWeb, :live_view

  alias AssetMonitoringDash.DemoData

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
        value: format_currency(snapshot.total_collateral_value_usd),
        delta: format_signed_percent(snapshot.collateral_delta_percent),
        delta_tone: :positive,
        icon: "hero-banknotes",
        description: "Marked value of monitored assets pledged against open credit."
      },
      %{
        id: "active-loans-card",
        label: "Active loans",
        value: Integer.to_string(snapshot.active_loans),
        delta: "+#{snapshot.active_loans_delta} today",
        delta_tone: :neutral,
        icon: "hero-document-chart-bar",
        description: "Open borrow positions using game assets as collateral."
      },
      %{
        id: "weighted-apy-card",
        label: "Weighted APY",
        value: "#{format_decimal(snapshot.weighted_apy_percent)}%",
        delta: format_signed_percent(snapshot.apy_delta_percent),
        delta_tone: :negative,
        icon: "hero-arrow-trending-up",
        description: "Portfolio-level annualized yield estimate across active positions."
      },
      %{
        id: "risk-score-card",
        label: "Risk score",
        value: "#{snapshot.risk_score}/100",
        delta: "+#{snapshot.risk_delta} risk",
        delta_tone: :warning,
        icon: "hero-shield-exclamation",
        description: "#{snapshot.risk_band} liquidation pressure across the monitored book."
      }
    ]
  end

  defp format_currency(value) when is_integer(value) do
    "$" <> delimited_integer(value)
  end

  defp delimited_integer(value) do
    value
    |> Integer.to_string()
    |> String.replace(~r/\B(?=(\d{3})+(?!\d))/, ",")
  end

  defp format_signed_percent(value) when value > 0, do: "+#{format_decimal(value)}%"
  defp format_signed_percent(value), do: "#{format_decimal(value)}%"

  defp format_decimal(value) do
    :erlang.float_to_binary(value / 1, decimals: 1)
  end

  defp delta_class(:positive), do: "bg-emerald-50 text-emerald-700 ring-emerald-600/15"
  defp delta_class(:negative), do: "bg-rose-50 text-rose-700 ring-rose-600/15"
  defp delta_class(:warning), do: "bg-amber-50 text-amber-800 ring-amber-600/20"
  defp delta_class(:neutral), do: "bg-slate-100 text-slate-700 ring-slate-500/15"
end
