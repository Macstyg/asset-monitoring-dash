defmodule AssetMonitoringDash.RiskRecommendationTest do
  use ExUnit.Case, async: true

  alias AssetMonitoringDash.Assets
  alias AssetMonitoringDash.RiskRecommendation

  test "derives system recommendation from the selected asset risk" do
    low_risk_asset = %{risk_band: "Low", oracle_status: "Fresh", liquidity_status: "Deep"}

    assert %{id: :clear, reasons: [%{id: :low_risk}]} =
             RiskRecommendation.recommendation_for(low_risk_asset)

    assert %{id: :watch, reasons: [%{id: :moderate_risk}]} =
             RiskRecommendation.recommendation_for(Assets.get_asset("asset-003"))

    assert %{id: :manual_review, reasons: [%{id: :elevated_risk}]} =
             RiskRecommendation.recommendation_for(Assets.get_asset("asset-001"))

    assert %{id: :liquidation_candidate, reasons: [%{id: :critical_health}]} =
             RiskRecommendation.recommendation_for(Assets.get_asset("asset-002"))
  end

  test "routes stale oracle data to manual review instead of automatic escalation" do
    assert Assets.get_asset("asset-010").risk_band == "Critical"
    assert Assets.get_asset("asset-010").oracle_status == "Stale"

    assert %{id: :manual_review, reasons: [%{id: :stale_oracle}]} =
             RiskRecommendation.recommendation_for(Assets.get_asset("asset-010"))

    assert Assets.get_asset("asset-004").risk_band == "Moderate"
    assert Assets.get_asset("asset-004").oracle_status == "Stale"

    assert %{id: :manual_review, reasons: [%{id: :stale_oracle}]} =
             RiskRecommendation.recommendation_for(Assets.get_asset("asset-004"))
  end

  test "routes illiquid markets to manual review even with fresh oracle data" do
    asset = Assets.get_asset("asset-012")

    assert asset.risk_band == "Moderate"
    assert asset.oracle_status == "Fresh"
    assert asset.liquidity_status == "Illiquid"

    assert %{id: :manual_review, reasons: [%{id: :illiquid_market}]} =
             RiskRecommendation.recommendation_for(asset)
  end

  test "routes low risk illiquid markets to watch" do
    asset = Assets.get_asset("asset-011")

    assert asset.risk_band == "Low"
    assert asset.oracle_status == "Fresh"
    assert asset.liquidity_status == "Illiquid"

    assert %{id: :watch, reasons: [%{id: :illiquid_market}]} =
             RiskRecommendation.recommendation_for(asset)
  end
end
