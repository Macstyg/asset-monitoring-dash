defmodule AssetMonitoringDash.DemoOperationsTest do
  use AssetMonitoringDash.DataCase, async: false

  alias AssetMonitoringDash.ActivityLog
  alias AssetMonitoringDash.Assets
  alias AssetMonitoringDash.AssetScenarioStore
  alias AssetMonitoringDash.DemoOperations
  alias AssetMonitoringDash.ReviewState
  alias AssetMonitoringDash.ReviewStore

  test "clears mutable demo state while keeping the seeded catalog" do
    asset = Assets.get_persisted_asset("asset-001")
    catalog_count = Assets.persisted_asset_count()

    AssetScenarioStore.apply_price_shock(asset.id)
    review_states = ReviewStore.mark_reviewed(asset.id)
    ActivityLog.record_review(asset, ReviewState.state(:reviewed))

    assert MapSet.size(AssetScenarioStore.shocked_asset_ids()) == 1
    assert ReviewStore.current_state(asset.id).id == :reviewed
    assert ReviewState.state_for(asset.id, review_states).id == :reviewed
    assert [_event] = ActivityLog.visible_events_for_asset(asset.id)

    assert DemoOperations.reset_mutable_state() == :ok

    assert AssetScenarioStore.shocked_asset_ids() == MapSet.new()
    assert ReviewStore.current_state(asset.id).id == :unreviewed
    assert ActivityLog.visible_events_for_asset(asset.id) == []
    assert Assets.persisted_asset_count() == catalog_count
  end

  test "applies a price shock and resets stale operator review state" do
    asset = Assets.get_persisted_asset("asset-001")

    ReviewStore.mark_reviewed(asset.id)

    assert ReviewStore.current_state(asset.id).id == :reviewed

    result = DemoOperations.apply_price_shock(asset.id)

    assert result.asset.id == asset.id
    assert Assets.asset_id_in_set?(asset.id, result.shocked_asset_ids)
    assert result.review_reset.decision.state_id == :unreviewed
    assert ReviewStore.current_state(asset.id).id == :unreviewed

    assert [
             %{id: "event-review-unreviewed-" <> _review_asset_id, kind: :operator},
             %{id: "event-shock-" <> _shock_asset_id, kind: :scenario}
             | _events
           ] = ActivityLog.visible_events_for_asset(asset.id)
  end

  test "applies non-price scenarios through the shared operation boundary" do
    asset = Assets.get_persisted_asset("asset-001")

    result = DemoOperations.apply_scenario(asset.id, "liquidity_thinning")

    assert result.asset.id == asset.id
    assert result.asset.liquidity_status == "Thin"
    assert result.scenario_id == "liquidity_thinning"

    assert [
             %{id: "event-liquidity_thinning-" <> _asset_id, kind: :scenario}
             | _events
           ] = ActivityLog.visible_events_for_asset(asset.id)
  end
end
