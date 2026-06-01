defmodule AssetMonitoringDash.Assets.PersistenceTest do
  use AssetMonitoringDash.DataCase, async: true

  alias AssetMonitoringDash.Assets
  alias AssetMonitoringDash.AssetScenario
  alias AssetMonitoringDash.AssetScenarioStore

  test "reads persisted assets in the same shape used by the dashboard" do
    assert %{
             id: id,
             chain: "Polygon",
             ecosystem: "Skyforge Arena",
             oracle_status: "Fresh",
             liquidity_status: "Deep"
           } = Enum.find(Assets.list_persisted_assets(), &(&1.dom_id == "asset-001"))

    assert Ecto.UUID.cast(id) == {:ok, id}
  end

  test "reads persisted market snapshots for an asset" do
    asset_id = Assets.persisted_asset_id("asset-001")
    snapshots = Assets.list_market_snapshots(asset_id)

    assert length(snapshots) == 7
    assert_decimal_equal(List.first(snapshots).ltv_percent, "56.5")
    assert_decimal_equal(List.last(snapshots).ltv_percent, "59.7")
    assert Enum.all?(snapshots, &(&1.asset_id == asset_id))
  end

  test "looks up a single persisted asset by UUID or legacy demo route id" do
    uuid = Assets.persisted_asset_id("asset-001")

    assert %{id: ^uuid, dom_id: "asset-001", name: "Aegis Dragon Helm"} =
             Assets.get_persisted_asset(uuid)

    assert %{id: ^uuid, dom_id: "asset-001", name: "Aegis Dragon Helm"} =
             Assets.get_persisted_asset("asset-001")
  end

  test "builds LTV trend from persisted market snapshots with current asset as latest point" do
    asset =
      "asset-001"
      |> AssetScenarioStore.apply_price_shock()
      |> then(&Assets.get_persisted_asset_with_scenarios("asset-001", &1))

    trend = Assets.ltv_trend(asset)

    assert length(trend) == 7
    assert %{label: "6d", value: first_value} = List.first(trend)
    assert %{label: "Now", value: last_value} = List.last(trend)
    assert_decimal_equal(first_value, "56.5")
    assert_decimal_equal(last_value, "67.8")
  end

  test "projects a persisted price drop and recalculates loan risk fields" do
    asset = Assets.price_drop_projection("asset-001", 12)

    assert_decimal_equal(asset.current_value_usd, "4276.80")
    assert_decimal_equal(asset.ltv_percent, "67.8")
    assert asset.risk_score == 80
    assert asset.risk_band == "Elevated"
  end

  test "pages persisted assets through the context query boundary" do
    page =
      Assets.list_persisted_assets_page(%{
        filters: %{Assets.default_filters() | query: "citadel", chains: ["Ethereum"]},
        sort: %{field: :asset, direction: :asc},
        limit: 1
      })

    assert page.total_count == 50
    assert page.next_cursor == 1
    assert page.summary.visible_count == 50
    assert [%{id: id, chain: "Ethereum", ecosystem: "Embervale"}] = page.entries
    assert id == Assets.persisted_asset_id("asset-002")

    next_page =
      Assets.list_persisted_assets_page(%{
        filters: %{Assets.default_filters() | query: "citadel", chains: ["Ethereum"]},
        sort: %{field: :asset, direction: :asc},
        cursor: page.next_cursor,
        limit: 1
      })

    assert next_page.next_cursor == 2
    assert [%{id: id}] = next_page.entries
    assert id == Assets.persisted_asset_id("asset-002-variant-001")
  end

  test "builds the portfolio snapshot from persisted aggregate queries" do
    snapshot = Assets.portfolio_snapshot()

    assert_decimal_equal(snapshot.total_collateral_value_usd, "3474032.80")
    assert_decimal_equal(snapshot.collateral_delta_percent, "0.0")
    assert snapshot.risk_score == 54
    assert snapshot.risk_delta == 0
    assert snapshot.risk_band == "Moderate"
  end

  test "applies scenario state to the persisted portfolio snapshot" do
    shocked_asset_ids = AssetScenarioStore.apply_price_shock("asset-001")

    snapshot = Assets.portfolio_snapshot(shocked_asset_ids)

    assert_decimal_equal(snapshot.total_collateral_value_usd, "3473449.60")
    assert_decimal_equal(snapshot.collateral_delta_percent, "0.0")
    assert snapshot.risk_score == 54
  end

  test "builds risk pressure buckets from scenario-adjusted assets" do
    baseline_buckets = Assets.risk_pressure_buckets()
    shocked_asset_ids = AssetScenarioStore.apply_price_shock("asset-004")

    adjusted_buckets = Assets.risk_pressure_buckets(shocked_asset_ids)

    assert Enum.map(baseline_buckets, & &1.label) == ["Low", "Moderate", "Elevated", "Critical"]
    assert Enum.sum(Enum.map(baseline_buckets, & &1.count)) == 600
    assert_decimal_equal(bucket(baseline_buckets, "Moderate").collateral_value_usd, "1278596.80")
    assert_decimal_equal(bucket(baseline_buckets, "Moderate").average_ltv_percent, "44.8")

    assert bucket(adjusted_buckets, "Moderate").count ==
             bucket(baseline_buckets, "Moderate").count - 1

    assert bucket(adjusted_buckets, "Elevated").count ==
             bucket(baseline_buckets, "Elevated").count + 1
  end

  test "applies scenario state on top of persisted assets before returning a page" do
    shocked_asset_ids = AssetScenarioStore.apply_price_shock("asset-001")

    page =
      Assets.list_persisted_assets_page(%{
        filters: %{Assets.default_filters() | query: "aegis"},
        sort: %{field: :asset, direction: :asc},
        shocked_asset_ids: shocked_asset_ids,
        limit: 1
      })

    assert page.total_count == 50
    assert [%{id: id} = asset] = page.entries
    assert id == Assets.persisted_asset_id("asset-001")
    assert_decimal_equal(asset.current_value_usd, "4276.80")
    assert_decimal_equal(asset.ltv_percent, "67.8")
  end

  test "filters persisted pages using scenario-adjusted risk bands" do
    shocked_asset_ids = AssetScenarioStore.apply_price_shock("asset-004")
    asset_id = Assets.persisted_asset_id("asset-004")

    page =
      Assets.list_persisted_assets_page(%{
        filters: %{
          Assets.default_filters()
          | query: "Ronin Warbeast",
            chains: ["Ronin"],
            risks: ["Elevated"]
        },
        sort: %{field: :asset, direction: :asc},
        shocked_asset_ids: shocked_asset_ids,
        limit: 50
      })

    assert Enum.any?(page.entries, &(&1.id == asset_id))
    assert %{risk_band: "Elevated"} = Enum.find(page.entries, &(&1.id == asset_id))
  end

  test "sorts persisted pages using scenario-adjusted numeric fields" do
    asset_id = Assets.persisted_asset_id("asset-011")
    AssetScenarioStore.apply_price_shock(asset_id)

    AssetScenario
    |> where([scenario], scenario.asset_id == ^asset_id)
    |> Repo.update_all(
      set: [
        current_value_usd: Decimal.new("999999.00"),
        ltv_percent: Decimal.new("99.9"),
        risk_band: "Critical",
        risk_score: 99
      ]
    )

    shocked_asset_ids = AssetScenarioStore.shocked_asset_ids()

    page =
      Assets.list_persisted_assets_page(%{
        filters: %{Assets.default_filters() | query: "Sealed Victory Crate"},
        sort: %{field: :value, direction: :desc},
        shocked_asset_ids: shocked_asset_ids,
        limit: 1
      })

    assert [%{id: ^asset_id} = asset] = page.entries
    assert_decimal_equal(asset.current_value_usd, "999999.00")
  end

  test "reads one persisted asset with scenario adjustments for detail pages" do
    asset =
      "asset-001"
      |> AssetScenarioStore.apply_price_shock()
      |> then(&Assets.get_persisted_asset_with_scenarios("asset-001", &1))

    assert_decimal_equal(asset.current_value_usd, "4276.80")
    assert_decimal_equal(asset.ltv_percent, "67.8")
    assert asset.risk_score == 80
  end

  test "returns bounded canonical related asset candidates from the database" do
    asset = Assets.get_persisted_asset("asset-001")

    candidates = Assets.list_related_asset_candidates(asset, MapSet.new(), limit: 20)

    refute candidates == []
    refute Enum.any?(candidates, &(&1.id == asset.id))
    refute Enum.any?(candidates, &String.contains?(&1.dom_id, "-variant-"))

    assert Enum.all?(candidates, fn candidate ->
             candidate.chain == asset.chain or
               candidate.ecosystem == asset.ecosystem or
               candidate.risk_band == asset.risk_band
           end)
  end

  defp assert_decimal_equal(actual, expected) do
    assert Decimal.equal?(actual, Decimal.new(expected))
  end

  defp bucket(buckets, label) do
    Enum.find(buckets, &(&1.label == label))
  end
end
