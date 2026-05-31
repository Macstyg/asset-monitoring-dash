defmodule AssetMonitoringDash.Assets.PersistenceTest do
  use AssetMonitoringDash.DataCase, async: true

  alias AssetMonitoringDash.Assets
  alias AssetMonitoringDash.Assets.Chain
  alias AssetMonitoringDash.Assets.GameEcosystem
  alias AssetMonitoringDash.Assets.MonitoredAsset

  test "persists the canonical demo asset catalog idempotently" do
    assert Assets.catalog_seeded?() == false

    persisted_assets = Assets.persist_demo_catalog!()

    assert length(persisted_assets) == 600
    assert Assets.catalog_seeded?()
    assert Repo.aggregate(Chain, :count) == 6
    assert Repo.aggregate(GameEcosystem, :count) == 6
    assert Repo.aggregate(MonitoredAsset, :count) == 600

    Assets.persist_demo_catalog!()

    assert Repo.aggregate(Chain, :count) == 6
    assert Repo.aggregate(GameEcosystem, :count) == 6
    assert Repo.aggregate(MonitoredAsset, :count) == 600
  end

  test "reads persisted assets in the same shape used by the dashboard" do
    Assets.persist_demo_catalog!()

    assert [
             %{
               id: "asset-001",
               chain: "Polygon",
               ecosystem: "Skyforge Arena",
               oracle_status: "Fresh",
               liquidity_status: "Deep"
             }
             | _assets
           ] = Assets.list_persisted_assets()
  end

  test "pages persisted assets through the context query boundary" do
    Assets.persist_demo_catalog!()

    page =
      Assets.list_persisted_assets_page(%{
        filters: %{Assets.default_filters() | query: "citadel", chains: ["Ethereum"]},
        sort: %{field: :asset, direction: :asc},
        limit: 1
      })

    assert page.total_count == 50
    assert page.next_cursor == 1
    assert page.summary.visible_count == 50
    assert [%{id: "asset-002", chain: "Ethereum", ecosystem: "Embervale"}] = page.entries

    next_page =
      Assets.list_persisted_assets_page(%{
        filters: %{Assets.default_filters() | query: "citadel", chains: ["Ethereum"]},
        sort: %{field: :asset, direction: :asc},
        cursor: page.next_cursor,
        limit: 1
      })

    assert next_page.next_cursor == 2
    assert [%{id: "asset-002-variant-001"}] = next_page.entries
  end

  test "applies scenario state on top of persisted assets before returning a page" do
    Assets.persist_demo_catalog!()

    page =
      Assets.list_persisted_assets_page(%{
        filters: %{Assets.default_filters() | query: "aegis"},
        sort: %{field: :asset, direction: :asc},
        shocked_asset_ids: MapSet.new(["asset-001"]),
        limit: 1
      })

    assert page.total_count == 50
    assert [%{id: "asset-001", current_value_usd: 4_277, ltv_percent: 67.8}] = page.entries
  end

  test "reads the persisted catalog with scenario adjustments for detail pages" do
    Assets.persist_demo_catalog!()

    asset =
      MapSet.new(["asset-001"])
      |> Assets.list_persisted_assets_with_scenarios()
      |> Assets.get_asset("asset-001")

    assert %{current_value_usd: 4_277, ltv_percent: 67.8, risk_score: 80} = asset
  end
end
