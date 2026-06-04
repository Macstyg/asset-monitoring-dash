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

  test "portfolio trends fall back while portfolio snapshots are still warming" do
    Repo.delete_all(PortfolioSnapshot)

    value_trend = Assets.portfolio_value_trend()
    risk_trend = Assets.portfolio_risk_trend()

    assert length(value_trend) == 7
    assert length(risk_trend) == 7
    assert List.last(value_trend).tooltip_value == "$3,474,033"
    assert List.last(risk_trend).tooltip_value == "54/100"
  end
end
