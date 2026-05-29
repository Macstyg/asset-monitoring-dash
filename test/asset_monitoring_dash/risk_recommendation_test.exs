defmodule AssetMonitoringDash.RiskRecommendationTest do
  use ExUnit.Case, async: true

  alias AssetMonitoringDash.Assets
  alias AssetMonitoringDash.RiskRecommendation

  test "derives system recommendation from the selected asset risk" do
    assert RiskRecommendation.recommendation_for(Assets.get_asset("asset-003")).id == :watch

    assert RiskRecommendation.recommendation_for(Assets.get_asset("asset-001")).id ==
             :manual_review

    assert RiskRecommendation.recommendation_for(Assets.get_asset("asset-010")).id ==
             :liquidation_candidate
  end
end
