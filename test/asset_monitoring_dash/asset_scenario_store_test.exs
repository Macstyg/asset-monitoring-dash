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

    AssetScenarioStore.apply_price_shock(asset_id)

    assert Repo.aggregate(AssetScenario, :count) == 1
  end

  test "resets one persisted scenario" do
    asset_id = Assets.resolve_persisted_asset_id("asset-001")

    AssetScenarioStore.apply_price_shock(asset_id)

    assert AssetScenarioStore.reset(asset_id) == MapSet.new()
    assert Repo.aggregate(AssetScenario, :count) == 0
  end
end
