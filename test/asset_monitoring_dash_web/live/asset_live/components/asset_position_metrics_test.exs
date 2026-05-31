defmodule AssetMonitoringDashWeb.AssetLive.Components.AssetPositionMetricsTest do
  use AssetMonitoringDashWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias AssetMonitoringDashWeb.AssetLive.Components.AssetPositionMetrics

  test "renders inspected asset identity and position metrics" do
    document =
      render_component(&AssetPositionMetrics.render/1,
        asset: asset(),
        health_factor: "1.7"
      )
      |> LazyHTML.from_fragment()

    text = LazyHTML.text(document)

    assert text =~ "Aegis Dragon Helm"
    assert text =~ "Polygon / Skyforge Arena"
    assert text =~ "$4,860"
    assert text =~ "$2,900"
    assert text =~ "59.7%"
    assert text =~ "1.7"
    assert text =~ "Fresh"
    assert text =~ "24s ago"
    assert text =~ "Deep"
    assert text =~ "$42,000 depth"
    assert document |> LazyHTML.query("#asset-ltv-tooltip") |> Enum.any?()
    assert document |> LazyHTML.query("#asset-health-tooltip") |> Enum.any?()
    assert document |> LazyHTML.query("#asset-oracle-tooltip") |> Enum.any?()
    assert document |> LazyHTML.query("#asset-liquidity-tooltip") |> Enum.any?()
  end

  defp asset do
    %{
      name: "Aegis Dragon Helm",
      icon: "dragon-helm.svg",
      chain: "Polygon",
      ecosystem: "Skyforge Arena",
      current_value_usd: 4_860,
      loan_value_usd: 2_900,
      ltv_percent: 59.7,
      oracle_status: "Fresh",
      oracle_freshness_seconds: 24,
      liquidity_status: "Deep",
      market_depth_usd: 42_000
    }
  end
end
