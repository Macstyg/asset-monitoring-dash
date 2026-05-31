defmodule AssetMonitoringDash.Assets.PersistenceTest do
  use AssetMonitoringDash.DataCase, async: false

  alias AssetMonitoringDash.Assets
  alias AssetMonitoringDash.Assets.Chain
  alias AssetMonitoringDash.Assets.GameEcosystem
  alias AssetMonitoringDash.Assets.MonitoredAsset
  alias AssetMonitoringDash.Seeds.DemoCatalog

  test "seeds the canonical demo asset catalog idempotently" do
    assert Assets.catalog_seeded?() == false

    persisted_assets = DemoCatalog.run!()

    assert length(persisted_assets) == 600
    assert Assets.catalog_seeded?()
    assert Repo.aggregate(Chain, :count) == 6
    assert Repo.aggregate(GameEcosystem, :count) == 6
    assert Repo.aggregate(MonitoredAsset, :count) == 600

    DemoCatalog.run!()

    assert Repo.aggregate(Chain, :count) == 6
    assert Repo.aggregate(GameEcosystem, :count) == 6
    assert Repo.aggregate(MonitoredAsset, :count) == 600
  end

  test "reads persisted assets in the same shape used by the dashboard" do
    DemoCatalog.run!()

    assert %{
             id: id,
             chain: "Polygon",
             ecosystem: "Skyforge Arena",
             oracle_status: "Fresh",
             liquidity_status: "Deep"
           } = Enum.find(Assets.list_persisted_assets(), &(&1.dom_id == "asset-001"))

    assert Ecto.UUID.cast(id) == {:ok, id}
  end

  test "pages persisted assets through the context query boundary" do
    DemoCatalog.run!()

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
    DemoCatalog.run!()

    page =
      Assets.list_persisted_assets_page(%{
        filters: %{Assets.default_filters() | query: "aegis"},
        sort: %{field: :asset, direction: :asc},
        shocked_asset_ids: MapSet.new(["asset-001"]),
        limit: 1
      })

    assert page.total_count == 50
    assert [%{id: id, current_value_usd: 4_277, ltv_percent: 67.8}] = page.entries
    assert id == Assets.persisted_asset_id("asset-001")
  end

  test "reads the persisted catalog with scenario adjustments for detail pages" do
    DemoCatalog.run!()

    asset =
      MapSet.new(["asset-001"])
      |> Assets.list_persisted_assets_with_scenarios()
      |> Assets.get_asset("asset-001")

    assert %{current_value_usd: 4_277, ltv_percent: 67.8, risk_score: 80} = asset
  end
end
