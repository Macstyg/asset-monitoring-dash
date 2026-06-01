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

  def event_source_buckets do
    EventStore.event_source_buckets()
  end

  def record_price_shock(asset, drop_percent) do
    EventStore.push_price_shock_event(asset, drop_percent)
  end

  def record_scenario(asset, scenario_id) do
    EventStore.push_scenario_event(asset, scenario_id)
  end

  def record_scenario_reset(asset) do
    EventStore.push_scenario_reset_event(asset)
  end

  def record_review(asset, review_state, review_audit \\ %{}) do
    EventStore.push_review_event(asset, review_state, review_audit)
  end

  def record_review_decision(asset, review_decision) do
    EventStore.push_review_decision_event(asset, review_decision)
  end

  def record_demo_event(next_event_index) do
    EventStore.push_demo_event(next_event_index)
  end

  def next_demo_event_index do
    EventStore.next_demo_event_index()
  end
end
