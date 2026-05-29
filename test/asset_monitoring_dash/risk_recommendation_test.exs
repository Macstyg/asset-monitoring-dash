defmodule AssetMonitoringDash.RiskRecommendationTest do
  use ExUnit.Case, async: true

  alias AssetMonitoringDash.Assets
  alias AssetMonitoringDash.RiskRecommendation

  test "derives system recommendation from the selected asset risk" do
    low_risk_asset = %{risk_band: "Low", oracle_status: "Fresh", liquidity_status: "Deep"}

    assert RiskRecommendation.recommendation_for(low_risk_asset).id == :clear
    assert RiskRecommendation.recommendation_for(Assets.get_asset("asset-003")).id == :watch

    assert RiskRecommendation.recommendation_for(Assets.get_asset("asset-001")).id ==
             :manual_review

    assert RiskRecommendation.recommendation_for(Assets.get_asset("asset-002")).id ==
             :liquidation_candidate
  end

  test "routes stale oracle data to manual review instead of automatic escalation" do
    assert Assets.get_asset("asset-010").risk_band == "Critical"
    assert Assets.get_asset("asset-010").oracle_status == "Stale"

    assert RiskRecommendation.recommendation_for(Assets.get_asset("asset-010")).id ==
             :manual_review

    assert Assets.get_asset("asset-004").risk_band == "Moderate"
    assert Assets.get_asset("asset-004").oracle_status == "Stale"

    assert RiskRecommendation.recommendation_for(Assets.get_asset("asset-004")).id ==
             :manual_review
  end

  test "routes illiquid markets to manual review even with fresh oracle data" do
    asset = Assets.get_asset("asset-012")

    assert asset.risk_band == "Moderate"
    assert asset.oracle_status == "Fresh"
    assert asset.liquidity_status == "Illiquid"

    assert RiskRecommendation.recommendation_for(asset).id == :manual_review
  end

  test "routes low risk illiquid markets to watch" do
    asset = Assets.get_asset("asset-011")

    assert asset.risk_band == "Low"
    assert asset.oracle_status == "Fresh"
    assert asset.liquidity_status == "Illiquid"

    assert RiskRecommendation.recommendation_for(asset).id == :watch
  end
end
