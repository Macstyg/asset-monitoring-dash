defmodule AssetMonitoringDashWeb.AssetLive.RelatedAssetRankerTest do
  use ExUnit.Case, async: true

  alias AssetMonitoringDashWeb.AssetLive.RelatedAssetRanker

  test "scores assets by chain, ecosystem, and risk-band matches" do
    asset = asset("asset-001", chain: "Polygon", ecosystem: "Skyforge", risk_band: "Elevated")

    assert RelatedAssetRanker.score(
             asset,
             asset("same-all", chain: "Polygon", ecosystem: "Skyforge", risk_band: "Elevated")
           ) == 6

    assert RelatedAssetRanker.score(
             asset,
             asset("same-chain", chain: "Polygon", ecosystem: "Other", risk_band: "Low")
           ) == 3

    assert RelatedAssetRanker.score(
             asset,
             asset("same-ecosystem", chain: "Base", ecosystem: "Skyforge", risk_band: "Low")
           ) == 2

    assert RelatedAssetRanker.score(
             asset,
             asset("same-risk", chain: "Base", ecosystem: "Other", risk_band: "Elevated")
           ) == 1
  end

  test "ranks canonical related assets by score, risk score, and name" do
    inspected = asset("asset-001", chain: "Polygon", ecosystem: "Skyforge", risk_band: "Elevated")

    related =
      RelatedAssetRanker.related_assets(
        inspected,
        [
          inspected,
          asset("asset-001-variant-001",
            chain: "Polygon",
            ecosystem: "Skyforge",
            risk_band: "Elevated"
          ),
          asset("unrelated", chain: "Base", ecosystem: "Rift", risk_band: "Low", risk_score: 99),
          asset("same-risk",
            chain: "Base",
            ecosystem: "Rift",
            risk_band: "Elevated",
            risk_score: 91
          ),
          asset("same-chain-a",
            chain: "Polygon",
            ecosystem: "Rift",
            risk_band: "Low",
            risk_score: 70
          ),
          asset("same-chain-b",
            chain: "Polygon",
            ecosystem: "Rift",
            risk_band: "Low",
            risk_score: 85
          ),
          asset("same-all",
            chain: "Polygon",
            ecosystem: "Skyforge",
            risk_band: "Elevated",
            risk_score: 65
          )
        ],
        limit: 3
      )

    assert Enum.map(related, & &1.id) == ["same-all", "same-chain-b", "same-chain-a"]
  end

  defp asset(id, attrs) do
    defaults = %{
      id: id,
      name: id,
      chain: "Polygon",
      ecosystem: "Skyforge",
      risk_band: "Moderate",
      risk_score: 50
    }

    Map.merge(defaults, Map.new(attrs))
  end
end
