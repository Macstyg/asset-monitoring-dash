defmodule AssetMonitoringDash.ReviewStateTest do
  use ExUnit.Case, async: true

  alias AssetMonitoringDash.ReviewState

  test "defaults positions to unreviewed" do
    assert ReviewState.state_for("asset-001", %{}).id == :unreviewed
  end

  test "tracks operator workflow state separately from system recommendations" do
    states =
      %{}
      |> ReviewState.mark_reviewed("asset-010")
      |> ReviewState.escalate("asset-003")

    assert ReviewState.state_for("asset-010", states).id == :reviewed
    assert ReviewState.state_for("asset-003", states).id == :escalated
  end

  test "resets one position to unreviewed" do
    states =
      %{}
      |> ReviewState.mark_reviewed("asset-001")
      |> ReviewState.reset("asset-001")

    assert ReviewState.state_for("asset-001", states).id == :unreviewed
  end
end
