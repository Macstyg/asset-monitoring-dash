defmodule AssetMonitoringDash.Assets.PersistenceSeedTest do
  use AssetMonitoringDash.DataCase, async: false

  alias AssetMonitoringDash.Assets
  alias AssetMonitoringDash.Assets.Chain
  alias AssetMonitoringDash.Assets.GameEcosystem
  alias AssetMonitoringDash.Assets.MarketSnapshot
  alias AssetMonitoringDash.Assets.MonitoredAsset
  alias AssetMonitoringDash.Assets.PortfolioSnapshot
  alias AssetMonitoringDash.Seeds.DemoCatalog

  test "seeds the canonical demo asset catalog idempotently" do
    persisted_assets = DemoCatalog.run!()

    assert length(persisted_assets) == 600
    assert Assets.catalog_seeded?()
    assert Repo.aggregate(Chain, :count) == 6
    assert Repo.aggregate(GameEcosystem, :count) == 6
    assert Repo.aggregate(MonitoredAsset, :count) == 600
    assert Repo.aggregate(MarketSnapshot, :count) == 4_200
    assert Repo.aggregate(PortfolioSnapshot, :count) == 7

    DemoCatalog.run!()

    assert Repo.aggregate(Chain, :count) == 6
    assert Repo.aggregate(GameEcosystem, :count) == 6
    assert Repo.aggregate(MonitoredAsset, :count) == 600
    assert Repo.aggregate(MarketSnapshot, :count) == 4_200
    assert Repo.aggregate(PortfolioSnapshot, :count) == 7
  end
end
