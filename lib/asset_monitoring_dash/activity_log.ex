defmodule AssetMonitoringDash.ActivityLog do
  @moduledoc """
  Boundary for recorded operational activity.

  LiveViews call this module instead of the lower-level event store so activity
  logging stays behind one product boundary.
  """

  alias AssetMonitoringDash.EventStore

  def visible_events do
    EventStore.visible_events()
  end

  def visible_events_for_asset(asset_id) do
    EventStore.visible_events_for_asset(asset_id)
  end

  def record_price_shock(asset, drop_percent) do
    EventStore.push_price_shock_event(asset, drop_percent)
  end

  def record_scenario_reset(asset) do
    EventStore.push_scenario_reset_event(asset)
  end

  def record_review(asset, review_state, review_audit \\ %{}) do
    EventStore.push_review_event(asset, review_state, review_audit)
  end
end
