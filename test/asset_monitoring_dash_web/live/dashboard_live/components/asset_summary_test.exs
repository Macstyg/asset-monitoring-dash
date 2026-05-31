defmodule AssetMonitoringDashWeb.DashboardLive.Components.AssetSummaryTest do
  use AssetMonitoringDashWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias AssetMonitoringDashWeb.DashboardLive.Components.AssetSummary

  test "renders the visible subset summary" do
    document =
      render_component(&AssetSummary.render/1,
        summary: %{
          visible_count: 12,
          total_value_usd: 42_500,
          at_risk_count: 3,
          highest_ltv_percent: 81.2
        }
      )
      |> LazyHTML.from_fragment()

    assert document |> LazyHTML.query("#asset-summary") |> Enum.any?()
    assert document |> LazyHTML.query("#asset-summary-visible-count") |> LazyHTML.text() =~ "12"
    assert document |> LazyHTML.query("#asset-summary-value") |> LazyHTML.text() =~ "$42,500"
    assert document |> LazyHTML.query("#asset-summary-at-risk") |> LazyHTML.text() =~ "3"
    assert document |> LazyHTML.query("#asset-summary-highest-ltv") |> LazyHTML.text() =~ "81.2%"
  end
end
