defmodule AssetMonitoringDash.DemoOperations do
  @moduledoc """
  Operational reset boundary for mutable demo data.

  The seeded catalog stays intact. This module only clears state produced while
  operating the demo: scenario overlays, review decisions, and generated events.
  """

  alias AssetMonitoringDash.ActivityLog
  alias AssetMonitoringDash.Assets
  alias AssetMonitoringDash.AssetScenarioStore
  alias AssetMonitoringDash.EventStore
  alias AssetMonitoringDash.ReviewStore

  def apply_price_shock(asset_id) do
    apply_scenario(asset_id, "price_shock")
  end

  def apply_scenario(asset_id, scenario_id) do
    shocked_asset_ids = AssetScenarioStore.apply_scenario(asset_id, scenario_id)
    asset = Assets.get_persisted_asset_with_scenarios(asset_id, shocked_asset_ids)

    ActivityLog.record_scenario(asset, scenario_id)
    review_reset = ReviewStore.reset_after_scenario(asset_id)

    record_review_decision(asset, review_reset.decision)

    %{
      asset: asset,
      event_history: ActivityLog.visible_events(),
      review_reset: review_reset,
      review_states: review_reset.states,
      scenario_id: scenario_id,
      shocked_asset_ids: shocked_asset_ids
    }
  end

  def reset_mutable_state do
    AssetScenarioStore.reset_all()
    ReviewStore.reset_all()
    EventStore.reset_mutable_events()

    :ok
  end

  defp record_review_decision(_asset, nil), do: :ok

  defp record_review_decision(asset, decision) do
    ActivityLog.record_review_decision(asset, decision)
  end
end
