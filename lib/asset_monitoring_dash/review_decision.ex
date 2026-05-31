defmodule AssetMonitoringDash.ReviewDecision do
  @moduledoc """
  Audit entry for an operator workflow state change.
  """

  alias AssetMonitoringDash.ReviewAudit
  alias AssetMonitoringDash.ReviewState

  @enforce_keys [
    :id,
    :asset_id,
    :state_id,
    :state_label,
    :state_tone,
    :actor,
    :audit,
    :occurred_at
  ]
  defstruct [
    :id,
    :asset_id,
    :state_id,
    :state_label,
    :state_tone,
    :actor,
    :audit,
    :occurred_at
  ]

  def operator(asset_id, review_state, audit_context) do
    build(asset_id, review_state, "Operator", audit_context)
  end

  def system_reset(asset_id) do
    build(
      asset_id,
      ReviewState.state(:unreviewed),
      "System",
      %{
        reason: "Scenario changed",
        note: "Operator state reset after scenario inputs changed."
      }
    )
  end

  defp build(asset_id, review_state, actor, audit_context) do
    %__MODULE__{
      id: decision_id(asset_id, review_state.id),
      asset_id: asset_id,
      state_id: review_state.id,
      state_label: review_state.label,
      state_tone: review_state.tone,
      actor: actor,
      audit: ReviewAudit.new(audit_context),
      occurred_at: DateTime.utc_now(:second)
    }
  end

  defp decision_id(asset_id, state_id) do
    sequence = System.unique_integer([:positive, :monotonic])

    "review-decision-#{asset_id}-#{state_id}-#{sequence}"
  end
end
