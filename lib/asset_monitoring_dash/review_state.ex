defmodule AssetMonitoringDash.ReviewState do
  @moduledoc """
  Operator-controlled review workflow state for monitored collateral positions.

  This state answers what a human has done with a system recommendation. It is
  separate from the recommendation itself.
  """

  @states %{
    unreviewed: %{
      id: :unreviewed,
      label: "Unreviewed",
      detail: "No operator has acknowledged the current recommendation.",
      tone: :neutral
    },
    reviewed: %{
      id: :reviewed,
      label: "Reviewed",
      detail: "An operator acknowledged the current recommendation.",
      tone: :success
    },
    escalated: %{
      id: :escalated,
      label: "Escalated",
      detail: "An operator escalated this position for follow-up.",
      tone: :warning
    }
  }

  def state_for(asset_id, states) do
    states
    |> Map.get(asset_id)
    |> normalize_state_id()
    |> state()
  end

  def mark_reviewed(states, asset_id) do
    Map.put(states, asset_id, :reviewed)
  end

  def escalate(states, asset_id) do
    Map.put(states, asset_id, :escalated)
  end

  def reset(states, asset_id) do
    Map.delete(states, asset_id)
  end

  def state(:unreviewed), do: @states.unreviewed
  def state(:reviewed), do: @states.reviewed
  def state(:escalated), do: @states.escalated

  defp normalize_state_id(state_id) when state_id in [:unreviewed, :reviewed, :escalated],
    do: state_id

  defp normalize_state_id(_state_id), do: :unreviewed
end
