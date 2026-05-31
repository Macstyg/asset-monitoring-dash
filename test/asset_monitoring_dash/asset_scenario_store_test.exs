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
    assert_decimal_equal(scenario.loan_value_usd, "2900.00")
    assert_decimal_equal(scenario.ltv_percent, "67.8")
    assert_decimal_equal(scenario.market_depth_usd, "42000.00")
    assert scenario.oracle_freshness_seconds == 24
    assert scenario.risk_score == 80
    assert scenario.risk_band == "Elevated"
    assert %DateTime{} = scenario.applied_at

    AssetScenarioStore.apply_price_shock(asset_id)

    assert Repo.aggregate(AssetScenario, :count) == 1
  end

  test "persists non-price scenario projections through the same store" do
    asset_id = Assets.resolve_persisted_asset_id("asset-001")

    active_asset_ids = AssetScenarioStore.apply_scenario("asset-001", "oracle_stale")

    assert MapSet.member?(active_asset_ids, asset_id)

    scenario = Repo.get_by!(AssetScenario, asset_id: asset_id, scenario_id: "oracle_stale")

    assert scenario.drop_percent == 0
    assert_decimal_equal(scenario.current_value_usd, "4860.00")
    assert_decimal_equal(scenario.loan_value_usd, "2900.00")
    assert_decimal_equal(scenario.ltv_percent, "59.7")
    assert_decimal_equal(scenario.market_depth_usd, "42000.00")
    assert scenario.oracle_freshness_seconds == 720

    active_asset_ids = AssetScenarioStore.apply_scenario("asset-001", "repayment")

    assert MapSet.member?(active_asset_ids, asset_id)
    assert Repo.aggregate(AssetScenario, :count) == 1

    scenario = Repo.get_by!(AssetScenario, asset_id: asset_id, scenario_id: "repayment")

    assert_decimal_equal(scenario.loan_value_usd, "2378.00")
    assert_decimal_equal(scenario.ltv_percent, "48.9")
    assert scenario.risk_band == "Moderate"
  end

  test "summarizes active scenarios by type" do
    AssetScenarioStore.apply_scenario("asset-001", "oracle_stale")
    AssetScenarioStore.apply_scenario("asset-002", "oracle_stale")
    AssetScenarioStore.apply_scenario("asset-003", "repayment")

    assert [
             %{id: "oracle_stale", label: "Oracle stale", count: 2},
             %{id: "repayment", label: "Repayment", count: 1}
           ] = AssetScenarioStore.active_summary()
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
