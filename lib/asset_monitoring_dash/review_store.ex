defmodule AssetMonitoringDash.ReviewStore do
  @moduledoc """
  Runtime store for demo operator review states.

  This gives separate LiveViews a shared view of what the operator has done
  without introducing database persistence before the workflow is settled.
  """

  use Agent

  alias AssetMonitoringDash.ReviewDecision
  alias AssetMonitoringDash.ReviewState

  @empty_store %{states: %{}, history: %{}}

  def start_link(opts) do
    Agent.start_link(fn -> @empty_store end, Keyword.put_new(opts, :name, __MODULE__))
  end

  def all_states do
    ensure_started()

    Agent.get(__MODULE__, &normalize_store(&1).states)
  end

  def history_for(asset_id) do
    ensure_started()

    Agent.get(__MODULE__, fn store ->
      store
      |> normalize_store()
      |> Map.fetch!(:history)
      |> Map.get(asset_id, [])
    end)
  end

  def mark_reviewed(asset_id, audit_context \\ %{}) do
    ensure_started()

    update_store(fn store ->
      put_operator_decision(store, asset_id, ReviewState.state(:reviewed), audit_context)
    end)
  end

  def escalate(asset_id, audit_context \\ %{}) do
    ensure_started()

    update_store(fn store ->
      put_operator_decision(store, asset_id, ReviewState.state(:escalated), audit_context)
    end)
  end

  def reset(asset_id) do
    ensure_started()

    update_store(fn store ->
      previous_state_id = Map.get(store.states, asset_id, :unreviewed)
      store = %{store | states: ReviewState.reset(store.states, asset_id)}

      case previous_state_id do
        :unreviewed -> store
        _state_id -> put_decision(store, asset_id, ReviewDecision.system_reset(asset_id))
      end
    end)
  end

  def reset_all do
    ensure_started()

    Agent.update(__MODULE__, fn _store -> @empty_store end)
  end

  defp ensure_started do
    case Process.whereis(__MODULE__) do
      nil -> start_standalone()
      _pid -> :ok
    end
  end

  defp start_standalone do
    case start_link([]) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end
  end

  defp update_store(fun) do
    Agent.get_and_update(__MODULE__, fn states ->
      store =
        states
        |> normalize_store()
        |> fun.()

      {store.states, store}
    end)
  end

  defp put_operator_decision(store, asset_id, review_state, audit_context) do
    store
    |> Map.update!(:states, fn states -> Map.put(states, asset_id, review_state.id) end)
    |> put_decision(asset_id, ReviewDecision.operator(asset_id, review_state, audit_context))
  end

  defp put_decision(store, asset_id, %ReviewDecision{} = decision) do
    Map.update!(store, :history, fn history ->
      Map.update(history, asset_id, [decision], &[decision | &1])
    end)
  end

  defp normalize_store(%{states: states, history: history}) do
    %{states: states, history: history}
  end

  defp normalize_store(states) when is_map(states) do
    %{states: states, history: %{}}
  end
end
