defmodule AssetMonitoringDash.RiskRecommendationTest do
  use ExUnit.Case, async: true

  alias AssetMonitoringDash.Assets
  alias AssetMonitoringDash.RiskRecommendation

  test "derives system recommendation from the selected asset risk" do
    assert RiskRecommendation.recommendation_for(Assets.get_asset("asset-011")).id == :clear
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
end
