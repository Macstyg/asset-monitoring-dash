defmodule AssetMonitoringDashWeb.AssetLive.ViewModelTest do
  use AssetMonitoringDash.DataCase, async: true

  alias AssetMonitoringDash.Assets
  alias AssetMonitoringDashWeb.AssetLive.ViewModel

  test "builds derived assigns for the asset detail page" do
    asset = Assets.get_persisted_asset("asset-001")

    view_model =
      ViewModel.build(asset,
        review_states: %{asset.id => :reviewed},
        shocked_asset_ids: MapSet.new()
      )

    assert view_model.page_title == "Aegis Dragon Helm · Asset detail"
    assert view_model.asset == asset
    assert view_model.asset_review_state.id == :reviewed
    assert view_model.asset_reviewed?
    refute view_model.asset_escalated?
    refute view_model.asset_shocked?
    assert view_model.active_scenario == nil
    assert view_model.asset_health_factor == "1.4"
    assert List.last(view_model.asset_ltv_trend).label == "Now"
    assert view_model.asset_risk_recommendation.label == "Manual review"
    assert view_model.asset_risk_explanation.headline == "Collateral buffer needs attention."
    assert length(view_model.related_assets) == 4
    refute Enum.any?(view_model.related_assets, &(&1.id == asset.id))
  end

  test "converts the view model to the assigns expected by the LiveView template" do
    asset = Assets.get_persisted_asset("asset-001")

    assigns =
      asset
      |> ViewModel.build(review_states: %{}, shocked_asset_ids: MapSet.new())
      |> ViewModel.assigns()

    assert assigns.asset == asset
    assert assigns.asset_review_state.id == :unreviewed
    assert assigns.page_title == "Aegis Dragon Helm · Asset detail"
    assert Map.has_key?(assigns, :related_assets)
    assert Map.has_key?(assigns, :review_history)
  end
end
