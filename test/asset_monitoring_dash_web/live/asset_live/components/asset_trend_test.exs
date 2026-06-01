defmodule AssetMonitoringDashWeb.AssetLive.Components.AssetTrendTest do
  use AssetMonitoringDashWeb.ComponentCase, async: true

  alias AssetMonitoringDashWeb.AssetLive.Components.AssetTrend

  test "renders an ECharts LTV trend with review thresholds" do
    document =
      render_component(&AssetTrend.render/1,
        points: [
          %{label: "6d", value: Decimal.new("56.5")},
          %{label: "5d", value: Decimal.new("58.1")},
          %{label: "Now", value: Decimal.new("59.7")}
        ]
      )
      |> LazyHTML.from_fragment()

    assert document |> LazyHTML.query("#asset-ltv-trend-latest") |> LazyHTML.text() =~ "59.7%"
    assert document |> LazyHTML.query("#asset-ltv-trend-delta") |> LazyHTML.text() =~ "+3.2 pts"

    option =
      document
      |> LazyHTML.query("#asset-ltv-trend-chart")
      |> LazyHTML.attribute("data-chart-option")
      |> List.first()
      |> Jason.decode!()

    assert get_in(option, ["series", Access.at(0), "type"]) == "line"
    assert get_in(option, ["tooltip", "titlePrefix"]) == "Observation"
    assert get_in(option, ["xAxis", "data"]) == ["6d", "5d", "Now"]

    assert option
           |> get_in(["series", Access.at(0), "markLine", "data"])
           |> Enum.map(& &1["name"]) == [
             "60% Watch",
             "75% Review",
             "80% Liquidation candidate"
           ]
  end
end
