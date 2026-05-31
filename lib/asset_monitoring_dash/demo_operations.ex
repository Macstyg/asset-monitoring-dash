defmodule AssetMonitoringDash.DemoOperations do
  @moduledoc """
  Operational reset boundary for mutable demo data.

  The seeded catalog stays intact. This module only clears state produced while
  operating the demo: scenario overlays, review decisions, and generated events.
  """

  alias AssetMonitoringDash.AssetScenarioStore
  alias AssetMonitoringDash.EventStore
  alias AssetMonitoringDash.ReviewStore

  def reset_mutable_state do
    AssetScenarioStore.reset_all()
    ReviewStore.reset_all()
    EventStore.reset_mutable_events()

    :ok
  end
end
