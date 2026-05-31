defmodule AssetMonitoringDash.ReviewStoreTest do
  use ExUnit.Case, async: false

  alias AssetMonitoringDash.ReviewDecision
  alias AssetMonitoringDash.ReviewStore

  setup do
    ReviewStore.reset_all()

    :ok
  end

  test "keeps current state map separate from decision history" do
    states =
      ReviewStore.mark_reviewed("asset-001", %{
        reason: "Oracle checked",
        note: "Feed matched."
      })

    assert states == %{"asset-001" => :reviewed}
    assert ReviewStore.all_states() == %{"asset-001" => :reviewed}

    assert [
             %ReviewDecision{
               actor: "Operator",
               asset_id: "asset-001",
               state_id: :reviewed,
               state_label: "Reviewed",
               audit: %{reason: "Oracle checked", note: "Feed matched."}
             }
           ] = ReviewStore.history_for("asset-001")
  end

  test "records a system reset only when an asset had operator state" do
    ReviewStore.mark_reviewed("asset-001")

    states = ReviewStore.reset("asset-001")

    assert states == %{}

    assert [
             %ReviewDecision{actor: "System", state_id: :unreviewed},
             %ReviewDecision{actor: "Operator", state_id: :reviewed}
           ] = ReviewStore.history_for("asset-001")

    ReviewStore.reset("asset-002")

    assert ReviewStore.history_for("asset-002") == []
  end
end
