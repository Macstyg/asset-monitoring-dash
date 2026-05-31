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
    latest_decision_records()
    |> current_states_from_records()
  end

  def current_state(asset_id) do
    asset_id
    |> current_state_id()
    |> ReviewState.state()
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
    asset_id
    |> reset_after_scenario()
    |> Map.fetch!(:states)
  end

  def reset_after_scenario(asset_id) do
    asset_id = Assets.resolve_persisted_asset_id(asset_id)

    case current_state_id(asset_id) do
      :unreviewed ->
        %{decision: nil, states: all_states()}

      _state_id ->
        decision =
          asset_id
          |> ReviewDecision.system_reset()
          |> persist_decision!()

        %{decision: decision, states: all_states()}
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
    |> record_to_decision()
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

  defp latest_decision_records do
    ReviewDecisionRecord
    |> distinct([decision], decision.asset_id)
    |> order_by([decision],
      asc: decision.asset_id,
      desc: decision.occurred_at,
      desc: decision.id
    )
    |> Repo.all()
  end

  defp current_state_id(asset_id) do
    asset_id = Assets.resolve_persisted_asset_id(asset_id)

    asset_id
    |> latest_decision_record_for()
    |> case do
      nil -> :unreviewed
      record -> state_atom(record.state_id)
    end
  end

  defp latest_decision_record_for(asset_id) do
    ReviewDecisionRecord
    |> where([decision], decision.asset_id == ^asset_id)
    |> order_by([decision], desc: decision.occurred_at, desc: decision.id)
    |> limit(1)
    |> Repo.one()
  end

  defp current_states_from_records(records) do
    Enum.reduce(records, %{}, fn record, states ->
      record.state_id
      |> state_atom()
      |> then(&put_current_state(states, record.asset_id, &1))
    end)
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
