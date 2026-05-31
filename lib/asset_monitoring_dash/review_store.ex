defmodule AssetMonitoringDash.ReviewStore do
  @moduledoc """
  Persistent boundary for operator review states and audit history.

  Review workflow is stored as an append-only decision log. The current state is
  derived from the latest decision for each asset, while `history_for/1` keeps
  the full audit trail visible on the asset detail page.
  """

  import Ecto.Query

  alias AssetMonitoringDash.Assets
  alias AssetMonitoringDash.Repo
  alias AssetMonitoringDash.ReviewAudit
  alias AssetMonitoringDash.ReviewDecision
  alias AssetMonitoringDash.ReviewDecisionRecord
  alias AssetMonitoringDash.ReviewState

  @state_atoms %{
    "unreviewed" => :unreviewed,
    "reviewed" => :reviewed,
    "escalated" => :escalated
  }

  def all_states do
    ReviewDecisionRecord
    |> order_by([decision],
      asc: decision.asset_id,
      desc: decision.occurred_at,
      desc: decision.id
    )
    |> Repo.all()
    |> current_states_from_records()
  end

  def history_for(asset_id) do
    asset_id = Assets.resolve_persisted_asset_id(asset_id)

    ReviewDecisionRecord
    |> where([decision], decision.asset_id == ^asset_id)
    |> order_by([decision], desc: decision.occurred_at, desc: decision.id)
    |> Repo.all()
    |> Enum.map(&record_to_decision/1)
  end

  def mark_reviewed(asset_id, audit_context \\ %{}) do
    asset_id = Assets.resolve_persisted_asset_id(asset_id)

    asset_id
    |> ReviewDecision.operator(ReviewState.state(:reviewed), audit_context)
    |> persist_decision!()

    all_states()
  end

  def escalate(asset_id, audit_context \\ %{}) do
    asset_id = Assets.resolve_persisted_asset_id(asset_id)

    asset_id
    |> ReviewDecision.operator(ReviewState.state(:escalated), audit_context)
    |> persist_decision!()

    all_states()
  end

  def reset(asset_id) do
    asset_id = Assets.resolve_persisted_asset_id(asset_id)
    states = all_states()

    case Map.get(states, asset_id, :unreviewed) do
      :unreviewed ->
        states

      _state_id ->
        asset_id
        |> ReviewDecision.system_reset()
        |> persist_decision!()

        all_states()
    end
  end

  def reset_all do
    Repo.delete_all(ReviewDecisionRecord)

    :ok
  end

  defp persist_decision!(%ReviewDecision{} = decision) do
    %ReviewDecisionRecord{}
    |> ReviewDecisionRecord.changeset(decision_attrs(decision))
    |> Repo.insert!()
  end

  defp decision_attrs(%ReviewDecision{} = decision) do
    audit = ReviewAudit.normalize(decision.audit)

    %{
      actor: decision.actor,
      asset_id: decision.asset_id,
      note: audit.note,
      occurred_at: decision.occurred_at,
      reason: audit.reason,
      state_id: Atom.to_string(decision.state_id)
    }
  end

  defp current_states_from_records(records) do
    records
    |> Enum.reduce({%{}, MapSet.new()}, &put_current_state_from_record/2)
    |> elem(0)
  end

  defp put_current_state_from_record(record, {states, seen_asset_ids}) do
    case MapSet.member?(seen_asset_ids, record.asset_id) do
      true ->
        {states, seen_asset_ids}

      false ->
        state_id = state_atom(record.state_id)
        states = put_current_state(states, record.asset_id, state_id)

        {states, MapSet.put(seen_asset_ids, record.asset_id)}
    end
  end

  defp put_current_state(states, _asset_id, :unreviewed), do: states
  defp put_current_state(states, asset_id, state_id), do: Map.put(states, asset_id, state_id)

  defp record_to_decision(record) do
    state = ReviewState.state(state_atom(record.state_id))

    %ReviewDecision{
      actor: record.actor,
      asset_id: record.asset_id,
      audit: ReviewAudit.new(%{note: record.note, reason: record.reason}),
      id: record.id,
      occurred_at: record.occurred_at,
      state_id: state.id,
      state_label: state.label,
      state_tone: state.tone
    }
  end

  defp state_atom(state_id), do: Map.get(@state_atoms, state_id, :unreviewed)
end
