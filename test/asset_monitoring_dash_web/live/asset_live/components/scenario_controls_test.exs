defmodule AssetMonitoringDashWeb.AssetLive.Components.ScenarioControlsTest do
  use AssetMonitoringDashWeb.ComponentCase, async: true

  alias AssetMonitoringDashWeb.AssetLive.Components.ScenarioControls

  test "renders enabled apply control before a scenario is active" do
    document =
      render_component(&ScenarioControls.render/1, asset_shocked?: false)
      |> LazyHTML.from_fragment()

    assert document |> LazyHTML.query("#asset-scenario-controls") |> Enum.any?()

    assert document
           |> LazyHTML.query(~s(button#apply-price-shock[phx-click="apply_price_shock"]))
           |> LazyHTML.text() =~ "Apply 12% price shock"

    refute document |> LazyHTML.query("#apply-price-shock[disabled]") |> Enum.any?()
    assert document |> LazyHTML.query("#reset-asset-scenario[disabled]") |> Enum.any?()
  end

  test "renders disabled apply control after a scenario is active" do
    document =
      render_component(&ScenarioControls.render/1, asset_shocked?: true)
      |> LazyHTML.from_fragment()

    assert document |> LazyHTML.query("#apply-price-shock") |> LazyHTML.text() =~ "Shock applied"
    assert document |> LazyHTML.query("#apply-price-shock[disabled]") |> Enum.any?()
    refute document |> LazyHTML.query("#reset-asset-scenario[disabled]") |> Enum.any?()
  end
end
