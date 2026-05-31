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
end
