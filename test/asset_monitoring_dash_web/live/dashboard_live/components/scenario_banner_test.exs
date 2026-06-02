defmodule AssetMonitoringDashWeb.DashboardLive.Components.ScenarioBannerTest do
  use AssetMonitoringDashWeb.ComponentCase, async: true

  alias AssetMonitoringDashWeb.DashboardLive.Components.ScenarioBanner

  test "renders active scenario state and reset action" do
    document =
      render_component(&ScenarioBanner.render/1, scenario_count: 2)
      |> LazyHTML.from_fragment()

    assert document |> LazyHTML.query("#active-scenario-banner") |> Enum.any?()

    assert document |> LazyHTML.query("#active-scenario-count") |> LazyHTML.text() =~
             "2 active scenarios"

    assert document
           |> LazyHTML.query(~s(button#reset-asset-scenarios[phx-click="reset_asset_scenarios"]))
           |> Enum.any?()
  end

  test "does not render when no scenario is active" do
    document =
      render_component(&ScenarioBanner.render/1, scenario_count: 0)
      |> LazyHTML.from_fragment()

    refute document |> LazyHTML.query("#active-scenario-banner") |> Enum.any?()
  end

  test "can hide reset action for view-only dashboards" do
    document =
      render_component(&ScenarioBanner.render/1,
        scenario_count: 2,
        demo_controls_enabled?: false
      )
      |> LazyHTML.from_fragment()

    assert document |> LazyHTML.query("#active-scenario-banner") |> Enum.any?()
    refute document |> LazyHTML.query("#reset-asset-scenarios") |> Enum.any?()
  end
end
