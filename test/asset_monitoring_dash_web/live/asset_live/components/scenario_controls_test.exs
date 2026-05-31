defmodule AssetMonitoringDashWeb.AssetLive.Components.ScenarioControlsTest do
  use AssetMonitoringDashWeb.ComponentCase, async: true

  alias AssetMonitoringDashWeb.AssetLive.Components.ScenarioControls

  test "renders enabled apply control before a scenario is active" do
    document =
      render_component(&ScenarioControls.render/1,
        active_scenario: nil,
        asset_shocked?: false,
        scenario_options: scenario_options()
      )
      |> LazyHTML.from_fragment()

    assert document |> LazyHTML.query("#asset-scenario-controls") |> Enum.any?()

    assert document
           |> LazyHTML.query(
             ~s(button#apply-asset-scenario-price_shock[phx-click="apply_asset_scenario"])
           )
           |> LazyHTML.text() =~ "Price shock"

    assert document
           |> LazyHTML.query(~s(button#apply-asset-scenario-oracle_stale))
           |> LazyHTML.text() =~ "Oracle stale"

    refute document
           |> LazyHTML.query("#apply-asset-scenario-price_shock[disabled]")
           |> Enum.any?()

    assert document |> LazyHTML.query("#reset-asset-scenario[disabled]") |> Enum.any?()
  end

  test "renders disabled apply control after a scenario is active" do
    document =
      render_component(&ScenarioControls.render/1,
        active_scenario: %{
          id: "oracle_stale",
          label: "Oracle stale",
          description: "Forces price-feed freshness outside the trusted window.",
          tone: :danger
        },
        asset_shocked?: true,
        scenario_options: scenario_options()
      )
      |> LazyHTML.from_fragment()

    assert document |> LazyHTML.query("#active-asset-scenario") |> LazyHTML.text() =~
             "Oracle stale"

    assert document |> LazyHTML.query("#active-asset-scenario") |> LazyHTML.text() =~
             "Forces price-feed freshness outside the trusted window."

    assert document |> LazyHTML.query("#apply-asset-scenario-oracle_stale") |> LazyHTML.text() =~
             "Oracle stale applied"

    assert document
           |> LazyHTML.query("#apply-asset-scenario-price_shock[disabled]")
           |> Enum.any?()

    refute document |> LazyHTML.query("#reset-asset-scenario[disabled]") |> Enum.any?()
  end

  defp scenario_options do
    [
      %{id: "price_shock", label: "Price shock", tone: :warning},
      %{
        id: "oracle_stale",
        label: "Oracle stale",
        description: "Forces price-feed freshness outside the trusted window.",
        tone: :danger
      }
    ]
    |> Enum.map(
      &Map.put_new(&1, :description, "Reprices collateral lower and raises LTV pressure.")
    )
  end
end
