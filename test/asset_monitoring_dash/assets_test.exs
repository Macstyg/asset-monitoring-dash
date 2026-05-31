defmodule AssetMonitoringDash.AssetsTest do
  use ExUnit.Case, async: true

  alias AssetMonitoringDash.Assets

  describe "list_assets/1" do
    test "returns all monitored assets with default filters" do
      assets = Assets.list_assets(Assets.default_filters())

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

    test "applies shared demo scenarios to the baseline asset book" do
      assets = Assets.list_assets_with_scenarios(MapSet.new(["asset-001"]))
      asset = Assets.get_asset(assets, "asset-001")
      untouched_asset = Assets.get_asset(assets, "asset-002")

      assert_decimal_equal(asset.current_value_usd, "4276.80")
      assert_decimal_equal(asset.ltv_percent, "67.8")
      assert_decimal_equal(untouched_asset.current_value_usd, "21150.00")
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
      filters = %{Assets.default_filters() | risks: ["Critical"]}
      ids = Enum.map(Assets.list_assets(filters), & &1.id)

      assert length(ids) == 14
      assert "asset-002" in ids
      assert "asset-010" in ids
      assert "asset-010-variant-005" in ids
    end

    test "filters by chain" do
      filters = %{Assets.default_filters() | chains: ["Arbitrum"]}
      ids = Enum.map(Assets.list_assets(filters), & &1.id)

      assert length(ids) == 100
      assert "asset-005" in ids
      assert "asset-010" in ids
      assert "asset-005-variant-001" in ids
    end

    test "filters by multiple selected values" do
      filters = %{
        Assets.default_filters()
        | risks: ["Low", "Critical"],
          chains: ["Ethereum", "Arbitrum"]
      }

      ids = Enum.map(Assets.list_assets(filters), & &1.id)

      assert length(ids) == 14
      assert "asset-002" in ids
      assert "asset-010" in ids
    end

    test "filters by system recommendation action" do
      manual_review_ids =
        Assets.default_filters()
        |> Map.put(:actions, ["manual_review"])
        |> Assets.list_assets()
        |> Enum.map(& &1.id)

      assert "asset-001" in manual_review_ids
      assert "asset-012" in manual_review_ids
      refute "asset-002" in manual_review_ids

      liquidation_ids =
        Assets.default_filters()
        |> Map.put(:actions, ["liquidation_candidate"])
        |> Assets.list_assets()
        |> Enum.map(& &1.id)

      assert length(liquidation_ids) == 4
      assert "asset-002" in liquidation_ids
      refute "asset-001" in liquidation_ids
    end

    test "filters by operator review state" do
      review_states = %{"asset-001" => :reviewed, "asset-003" => :escalated}

      reviewed_ids =
        Assets.default_filters()
        |> Map.put(:operator_states, ["reviewed"])
        |> Assets.list_assets(review_states)
        |> Enum.map(& &1.id)

      escalated_ids =
        Assets.default_filters()
        |> Map.put(:operator_states, ["escalated"])
        |> Assets.list_assets(review_states)
        |> Enum.map(& &1.id)

      unreviewed_ids =
        Assets.default_filters()
        |> Map.put(:operator_states, ["unreviewed"])
        |> Assets.list_assets(review_states)
        |> Enum.map(& &1.id)

      assert reviewed_ids == ["asset-001"]
      assert escalated_ids == ["asset-003"]
      assert length(unreviewed_ids) == 598
      refute "asset-001" in unreviewed_ids
      refute "asset-003" in unreviewed_ids
    end

    test "combines risk, chain, and query filters" do
      filters = %{query: "mech", risk: "Critical", chain: "Arbitrum"}
      ids = Enum.map(Assets.list_assets(filters), & &1.id)

      assert length(ids) == 13
      assert "asset-010" in ids
      assert "asset-010-variant-005" in ids
    end
  end

  describe "list_assets_page/1" do
    test "returns the first page plus count, summary, and cursor" do
      page =
        Assets.list_assets_page(%{
          filters: Assets.default_filters(),
          sort: %{field: :ltv, direction: :desc},
          cursor: nil,
          limit: 50,
          review_states: %{},
          shocked_asset_ids: MapSet.new()
        })

      assert length(page.entries) == 50
      assert page.total_count == 600
      assert page.next_cursor == 50
      assert page.summary.visible_count == 600
      assert List.first(page.entries).id == "asset-010"
    end

    test "returns later pages without duplicating previous rows" do
      first_page =
        Assets.list_assets_page(%{
          filters: Assets.default_filters(),
          sort: %{field: :ltv, direction: :desc},
          cursor: nil,
          limit: 50,
          review_states: %{},
          shocked_asset_ids: MapSet.new()
        })

      second_page =
        Assets.list_assets_page(%{
          filters: Assets.default_filters(),
          sort: %{field: :ltv, direction: :desc},
          cursor: first_page.next_cursor,
          limit: 50,
          review_states: %{},
          shocked_asset_ids: MapSet.new()
        })

      first_ids = MapSet.new(Enum.map(first_page.entries, & &1.id))
      second_ids = MapSet.new(Enum.map(second_page.entries, & &1.id))

      assert MapSet.disjoint?(first_ids, second_ids)
      assert second_page.next_cursor == 100
    end

    test "summarizes the full filtered result, not only the current page" do
      page =
        Assets.list_assets_page(%{
          filters: %{Assets.default_filters() | chains: ["Arbitrum"]},
          sort: %{field: :ltv, direction: :desc},
          cursor: nil,
          limit: 10,
          review_states: %{},
          shocked_asset_ids: MapSet.new()
        })

      assert length(page.entries) == 10
      assert page.total_count == 100
      assert page.summary.visible_count == 100
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

    assert_decimal_equal(asset.current_value_usd, "4276.80")
    assert_decimal_equal(asset.ltv_percent, "67.8")
    assert asset.risk_score == 80
    assert asset.risk_band == "Elevated"
  end

  test "resets one changed asset back to its baseline values" do
    assets =
      Assets.list_assets()
      |> Assets.apply_price_drop("asset-001", 12)
      |> Assets.reset_asset("asset-001")

    asset = Assets.get_asset(assets, "asset-001")

    assert_decimal_equal(asset.current_value_usd, "4860.00")
    assert_decimal_equal(asset.ltv_percent, "59.7")
    assert asset.risk_score == 70
  end

  test "builds an LTV trend with the current asset as the latest point" do
    asset =
      Assets.list_assets()
      |> Assets.apply_price_drop("asset-001", 12)
      |> Assets.get_asset("asset-001")

    trend = Assets.ltv_trend(asset)

    assert length(trend) == 7
    assert %{label: "6d", value: first_value} = List.first(trend)
    assert %{label: "Now", value: last_value} = List.last(trend)
    assert_decimal_equal(first_value, "56.5")
    assert_decimal_equal(last_value, "67.8")
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
