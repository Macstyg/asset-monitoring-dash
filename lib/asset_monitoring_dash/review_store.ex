defmodule AssetMonitoringDash.ReviewStore do
  @moduledoc """
  Runtime store for demo operator review states.

  This gives separate LiveViews a shared view of what the operator has done
  without introducing database persistence before the workflow is settled.
  """

  use Agent

  alias AssetMonitoringDash.ReviewState

  def start_link(opts) do
    Agent.start_link(fn -> %{} end, Keyword.put_new(opts, :name, __MODULE__))
  end

  def all_states do
    ensure_started()

    Agent.get(__MODULE__, & &1)
  end

  def mark_reviewed(asset_id) do
    ensure_started()

    update_states(&ReviewState.mark_reviewed(&1, asset_id))
  end

  def escalate(asset_id) do
    ensure_started()

    update_states(&ReviewState.escalate(&1, asset_id))
  end

  def reset(asset_id) do
    ensure_started()

    update_states(&ReviewState.reset(&1, asset_id))
  end

  def reset_all do
    ensure_started()

    Agent.update(__MODULE__, fn _states -> %{} end)
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

  defp update_states(fun) do
    Agent.get_and_update(__MODULE__, fn states ->
      states = fun.(states)

      {states, states}
    end)
  end
end
