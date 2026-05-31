defmodule AssetMonitoringDash.Assets.PersistenceTest do
  use AssetMonitoringDash.DataCase, async: true

  alias AssetMonitoringDash.Assets
  alias AssetMonitoringDash.Assets.Chain
  alias AssetMonitoringDash.Assets.GameEcosystem
  alias AssetMonitoringDash.Assets.MonitoredAsset

  test "persists the canonical demo asset catalog idempotently" do
    assert Assets.catalog_seeded?() == false

    persisted_assets = Assets.persist_demo_catalog!()

    assert length(persisted_assets) == 12
    assert Assets.catalog_seeded?()
    assert Repo.aggregate(Chain, :count) == 6
    assert Repo.aggregate(GameEcosystem, :count) == 6
    assert Repo.aggregate(MonitoredAsset, :count) == 12

    Assets.persist_demo_catalog!()

    assert Repo.aggregate(Chain, :count) == 6
    assert Repo.aggregate(GameEcosystem, :count) == 6
    assert Repo.aggregate(MonitoredAsset, :count) == 12
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
        filters: %{Assets.default_filters() | query: "ember", chains: ["Ethereum"]},
        sort: %{field: :ltv, direction: :desc},
        limit: 1
      })

    assert page.total_count == 2
    assert page.next_cursor == 1
    assert page.summary.visible_count == 2
    assert [%{id: "asset-002", chain: "Ethereum", ecosystem: "Embervale"}] = page.entries

    next_page =
      Assets.list_persisted_assets_page(%{
        filters: %{Assets.default_filters() | query: "ember", chains: ["Ethereum"]},
        sort: %{field: :ltv, direction: :desc},
        cursor: page.next_cursor,
        limit: 1
      })

    assert next_page.next_cursor == nil
    assert [%{id: "asset-007"}] = next_page.entries
  end
end
