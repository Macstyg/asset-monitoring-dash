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
