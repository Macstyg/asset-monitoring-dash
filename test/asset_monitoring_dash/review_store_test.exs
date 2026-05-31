defmodule AssetMonitoringDash.ReviewStoreTest do
  use AssetMonitoringDash.DataCase, async: true

  alias AssetMonitoringDash.ReviewDecision
  alias AssetMonitoringDash.ReviewStore

  test "keeps current state map separate from decision history" do
    asset_id = asset_id("asset-001")

    states =
      ReviewStore.mark_reviewed("asset-001", %{
        reason: "Oracle checked",
        note: "Feed matched."
      })

    assert states == %{asset_id => :reviewed}
    assert ReviewStore.all_states() == %{asset_id => :reviewed}
    assert ReviewStore.current_state("asset-001").id == :reviewed

    assert [
             %ReviewDecision{
               actor: "Operator",
               asset_id: ^asset_id,
               state_id: :reviewed,
               state_label: "Reviewed",
               audit: %{reason: "Oracle checked", note: "Feed matched."}
             }
           ] = ReviewStore.history_for("asset-001")
  end

  test "derives current state from the latest persisted decision" do
    asset_id = asset_id("asset-001")

    ReviewStore.mark_reviewed("asset-001")
    ReviewStore.escalate("asset-001")

    assert ReviewStore.all_states() == %{asset_id => :escalated}
    assert ReviewStore.current_state("asset-001").id == :escalated

    assert [
             %ReviewDecision{state_id: :escalated},
             %ReviewDecision{state_id: :reviewed}
           ] = ReviewStore.history_for("asset-001")
  end

  test "records a system reset only when an asset had operator state" do
    asset_id = asset_id("asset-001")

    ReviewStore.mark_reviewed("asset-001")

    states = ReviewStore.reset("asset-001")

    assert states == %{}

    assert [
             %ReviewDecision{actor: "System", state_id: :unreviewed},
             %ReviewDecision{actor: "Operator", state_id: :reviewed}
           ] = ReviewStore.history_for("asset-001")

    assert Enum.all?(ReviewStore.history_for("asset-001"), &(&1.asset_id == asset_id))

    ReviewStore.reset("asset-002")

    assert ReviewStore.history_for("asset-002") == []
  end

  test "returns the persisted reset decision for scenario-driven workflow resets" do
    asset_id = asset_id("asset-001")

    ReviewStore.mark_reviewed("asset-001")

    assert %{
             decision: %ReviewDecision{
               actor: "System",
               asset_id: ^asset_id,
               state_id: :unreviewed,
               state_label: "Unreviewed",
               audit: %{reason: "Scenario changed"}
             },
             states: %{}
           } = ReviewStore.reset_after_scenario("asset-001")

    assert %{decision: nil, states: %{}} = ReviewStore.reset_after_scenario("asset-001")
  end

  defp asset_id(code), do: AssetMonitoringDash.Assets.resolve_persisted_asset_id(code)
end
