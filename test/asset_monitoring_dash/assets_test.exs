defmodule AssetMonitoringDash.AssetsTest do
  use ExUnit.Case, async: true

  alias AssetMonitoringDash.Assets

  describe "list_assets/1" do
    test "returns all monitored assets with default filters" do
      assets = Assets.list_assets()

      assert length(assets) == 600
      assert Enum.any?(assets, &(&1.id == "asset-001"))
      assert Enum.any?(assets, &(&1.id == "asset-001-variant-001"))
      assert Enum.any?(assets, &(&1.id == "asset-010"))
    end

    test "derives loan risk fields from current value and loan value" do
      asset = Assets.get_asset("asset-001")

      assert_decimal_equal(asset.ltv_percent, "59.7")
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

  test "uses different LTV trend shapes for different assets" do
    improving_asset = Assets.get_asset("asset-003")
    volatile_asset = Assets.get_asset("asset-010")

    improving_trend = Assets.ltv_trend(improving_asset)
    volatile_trend = Assets.ltv_trend(volatile_asset)

    assert Enum.map(improving_trend, &decimal_string(&1.value)) == [
             "40.2",
             "39.6",
             "38.9",
             "38.3",
             "37.7",
             "37.4",
             "37.8"
           ]

    assert Enum.map(volatile_trend, &decimal_string(&1.value)) == [
             "74.5",
             "77.0",
             "75.7",
             "78.4",
             "81.0",
             "82.9",
             "80.1"
           ]
  end

  test "summarizes a list of visible assets" do
    summary =
      [Assets.get_asset("asset-002"), Assets.get_asset("asset-010")]
      |> Assets.summarize_assets()

    assert summary.visible_count == 2
    assert_decimal_equal(summary.total_value_usd, "29910.00")
    assert summary.at_risk_count == 2
    assert_decimal_equal(summary.average_ltv_percent, "77.7")
    assert_decimal_equal(summary.highest_ltv_percent, "80.1")
  end

  test "summarizes an empty asset list" do
    assert Assets.summarize_assets([]) == %{
             visible_count: 0,
             total_value_usd: Decimal.new("0.00"),
             at_risk_count: 0,
             average_ltv_percent: Decimal.new("0.0"),
             highest_ltv_percent: Decimal.new("0.0")
           }
  end

  test "normalizes invalid filter values back to defaults" do
    filters =
      Assets.normalize_filters(
        %{"query" => "  MECH  ", "risk" => "Severe", "chain" => "Solana"},
        Assets.default_filters()
      )

    assert filters == %{
             query: "mech",
             risks: [],
             chains: [],
             actions: [],
             operator_states: [],
             risk_option_query: "",
             chain_option_query: "",
             action_option_query: "",
             operator_state_option_query: ""
           }
  end

  test "builds filter options from monitored assets" do
    assert %{label: "Critical", value: "Critical"} = List.last(Assets.risk_filter_options())

    assert %{label: "Manual review", value: "manual_review"} =
             List.first(Assets.action_filter_options())

    assert %{
             label: "Reviewed",
             value: "reviewed",
             icon_text: "R",
             tone: :success
           } in Assets.operator_state_filter_options()

    assert %{label: "Arbitrum", value: "Arbitrum", icon: :chain} in Assets.chain_filter_options()
    assert %{label: "Polygon", value: "Polygon", icon: :chain} in Assets.chain_filter_options()
  end

  test "filters option lists by search query" do
    assert Assets.filter_options(Assets.chain_filter_options(), "poly") == [
             %{label: "Polygon", value: "Polygon", icon: :chain}
           ]
  end

  defp assert_decimal_equal(actual, expected) do
    assert Decimal.equal?(actual, Decimal.new(expected))
  end

  defp decimal_string(value) do
    Decimal.to_string(value, :normal)
  end
end
