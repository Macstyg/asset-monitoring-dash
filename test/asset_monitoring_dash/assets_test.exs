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
