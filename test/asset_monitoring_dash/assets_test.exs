defmodule AssetMonitoringDash.AssetsTest do
  use ExUnit.Case, async: true

  alias AssetMonitoringDash.Assets

  describe "list_assets/1" do
    test "returns all monitored assets with default filters" do
      assets = Assets.list_assets(Assets.default_filters())

      assert length(assets) == 12
      assert Enum.any?(assets, &(&1.id == "asset-001"))
      assert Enum.any?(assets, &(&1.id == "asset-010"))
    end

    test "derives loan risk fields from current value and loan value" do
      asset = Assets.get_asset("asset-001")

      assert asset.ltv_percent == 59.7
      assert asset.risk_score == 70
      assert asset.risk_band == "Elevated"
    end

    test "derives oracle status from freshness seconds" do
      assert Assets.oracle_status(24) == "Fresh"
      assert Assets.oracle_status(184) == "Delayed"
      assert Assets.oracle_status(620) == "Stale"
      assert Assets.get_asset("asset-004").oracle_status == "Stale"
    end

    test "derives liquidity status from market depth" do
      assert Assets.liquidity_status(42_000) == "Deep"
      assert Assets.liquidity_status(12_800) == "Thin"
      assert Assets.liquidity_status(2_750) == "Illiquid"
      assert Assets.get_asset("asset-009").liquidity_status == "Illiquid"
    end

    test "filters by risk band" do
      filters = %{Assets.default_filters() | risk: "Critical"}

      assert Enum.map(Assets.list_assets(filters), & &1.id) == ["asset-002", "asset-010"]
    end

    test "filters by chain" do
      filters = %{Assets.default_filters() | chain: "Arbitrum"}

      assert Enum.map(Assets.list_assets(filters), & &1.id) == ["asset-005", "asset-010"]
    end

    test "combines risk, chain, and query filters" do
      filters = %{query: "mech", risk: "Critical", chain: "Arbitrum"}

      assert Enum.map(Assets.list_assets(filters), & &1.id) == ["asset-010"]
    end
  end

  test "gets one asset by id" do
    assert %{name: "Ancient Mech Core"} = Assets.get_asset("asset-010")
    assert is_nil(Assets.get_asset("missing-asset"))
  end

  test "gets one asset by id from a supplied asset book" do
    assets = Assets.list_assets()

    assert %{name: "Aegis Dragon Helm"} = Assets.get_asset(assets, "asset-001")
    assert is_nil(Assets.get_asset(assets, "missing-asset"))
  end

  test "applies a price drop and recalculates loan risk fields" do
    [asset] =
      Assets.list_assets()
      |> Assets.apply_price_drop("asset-001", 12)
      |> Enum.filter(&(&1.id == "asset-001"))

    assert asset.current_value_usd == 4_277
    assert asset.ltv_percent == 67.8
    assert asset.risk_score == 80
    assert asset.risk_band == "Elevated"
  end

  test "resets one changed asset back to its baseline values" do
    assets =
      Assets.list_assets()
      |> Assets.apply_price_drop("asset-001", 12)
      |> Assets.reset_asset("asset-001")

    assert %{current_value_usd: 4_860, ltv_percent: 59.7, risk_score: 70} =
             Assets.get_asset(assets, "asset-001")
  end

  test "builds an LTV trend with the current asset as the latest point" do
    asset =
      Assets.list_assets()
      |> Assets.apply_price_drop("asset-001", 12)
      |> Assets.get_asset("asset-001")

    trend = Assets.ltv_trend(asset)

    assert length(trend) == 7
    assert List.first(trend) == %{label: "6d", value: 56.5}
    assert List.last(trend) == %{label: "Now", value: 67.8}
  end

  test "uses different LTV trend shapes for different assets" do
    improving_asset = Assets.get_asset("asset-003")
    volatile_asset = Assets.get_asset("asset-010")

    improving_trend = Assets.ltv_trend(improving_asset)
    volatile_trend = Assets.ltv_trend(volatile_asset)

    assert Enum.map(improving_trend, & &1.value) == [40.2, 39.6, 38.9, 38.3, 37.7, 37.4, 37.8]
    assert Enum.map(volatile_trend, & &1.value) == [74.5, 77.0, 75.7, 78.4, 81.0, 82.9, 80.1]
  end

  test "summarizes a list of visible assets" do
    summary =
      Assets.default_filters()
      |> Map.put(:risk, "Critical")
      |> Assets.list_assets()
      |> Assets.summarize_assets()

    assert summary.visible_count == 2
    assert summary.total_value_usd == 29_910
    assert summary.at_risk_count == 2
    assert_in_delta summary.average_ltv_percent, 77.65, 0.001
    assert summary.highest_ltv_percent == 80.1
  end

  test "summarizes an empty asset list" do
    assert Assets.summarize_assets([]) == %{
             visible_count: 0,
             total_value_usd: 0,
             at_risk_count: 0,
             average_ltv_percent: 0.0,
             highest_ltv_percent: 0.0
           }
  end

  test "normalizes invalid filter values back to defaults" do
    filters =
      Assets.normalize_filters(
        %{"query" => "  MECH  ", "risk" => "Severe", "chain" => "Solana"},
        Assets.default_filters()
      )

    assert filters == %{query: "mech", risk: "All", chain: "All chains"}
  end

  test "builds filter options from monitored assets" do
    assert {"All risk tiers", "All"} in Assets.risk_filter_options()
    assert {"Arbitrum", "Arbitrum"} in Assets.chain_filter_options()
    assert {"Polygon", "Polygon"} in Assets.chain_filter_options()
  end
end
