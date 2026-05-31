defmodule AssetMonitoringDash.Assets.PersistenceTest do
  use AssetMonitoringDash.DataCase, async: true

  alias AssetMonitoringDash.Assets
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

  test "builds LTV trend from persisted market snapshots with current asset as latest point" do
    asset =
      "asset-001"
      |> AssetScenarioStore.apply_price_shock()
      |> Assets.list_persisted_assets_with_scenarios()
      |> Assets.get_asset("asset-001")

    trend = Assets.ltv_trend(asset)

    assert length(trend) == 7
    assert %{label: "6d", value: first_value} = List.first(trend)
    assert %{label: "Now", value: last_value} = List.last(trend)
    assert_decimal_equal(first_value, "56.5")
    assert_decimal_equal(last_value, "67.8")
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

  test "reads the persisted catalog with scenario adjustments for detail pages" do
    asset =
      "asset-001"
      |> AssetScenarioStore.apply_price_shock()
      |> Assets.list_persisted_assets_with_scenarios()
      |> Assets.get_asset("asset-001")

    assert_decimal_equal(asset.current_value_usd, "4276.80")
    assert_decimal_equal(asset.ltv_percent, "67.8")
    assert asset.risk_score == 80
  end

  defp assert_decimal_equal(actual, expected) do
    assert Decimal.equal?(actual, Decimal.new(expected))
  end
end
