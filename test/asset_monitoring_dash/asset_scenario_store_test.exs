defmodule AssetMonitoringDash.AssetScenarioStoreTest do
  use AssetMonitoringDash.DataCase, async: true

  alias AssetMonitoringDash.Assets
  alias AssetMonitoringDash.AssetScenario
  alias AssetMonitoringDash.AssetScenarioStore

  test "persists active price shock scenarios by asset id" do
    asset_id = Assets.resolve_persisted_asset_id("asset-001")

    shocked_asset_ids = AssetScenarioStore.apply_price_shock("asset-001")

    assert MapSet.member?(shocked_asset_ids, asset_id)
    assert Repo.aggregate(AssetScenario, :count) == 1

    scenario = Repo.get_by!(AssetScenario, asset_id: asset_id, scenario_id: "price_shock")

    assert scenario.drop_percent == 12
    assert_decimal_equal(scenario.current_value_usd, "4276.80")
    assert_decimal_equal(scenario.ltv_percent, "67.8")
    assert scenario.risk_score == 80
    assert scenario.risk_band == "Elevated"
    assert %DateTime{} = scenario.applied_at

    AssetScenarioStore.apply_price_shock(asset_id)

    assert Repo.aggregate(AssetScenario, :count) == 1
  end

  test "resets one persisted scenario" do
    asset_id = Assets.resolve_persisted_asset_id("asset-001")

    AssetScenarioStore.apply_price_shock(asset_id)

    assert AssetScenarioStore.reset(asset_id) == MapSet.new()
    assert Repo.aggregate(AssetScenario, :count) == 0
  end

  defp assert_decimal_equal(actual, expected) do
    assert Decimal.equal?(actual, Decimal.new(expected))
  end
end
