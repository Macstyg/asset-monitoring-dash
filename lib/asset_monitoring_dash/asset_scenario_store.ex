defmodule AssetMonitoringDash.AssetScenarioStore do
  @moduledoc """
  Runtime store for demo asset scenarios.

  This keeps scenario controls visible across LiveViews without introducing
  database persistence before the demo workflow has settled.
  """

  use Agent

  def start_link(opts) do
    Agent.start_link(fn -> MapSet.new() end, Keyword.put_new(opts, :name, __MODULE__))
  end

  def shocked_asset_ids do
    ensure_started()

    Agent.get(__MODULE__, & &1)
  end

  def apply_price_shock(asset_id) do
    ensure_started()

    update_shocked_asset_ids(&MapSet.put(&1, asset_id))
  end

  def reset(asset_id) do
    ensure_started()

    update_shocked_asset_ids(&MapSet.delete(&1, asset_id))
  end

  def reset_all do
    ensure_started()

    Agent.update(__MODULE__, fn _asset_ids -> MapSet.new() end)
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

  defp update_shocked_asset_ids(fun) do
    Agent.get_and_update(__MODULE__, fn asset_ids ->
      asset_ids = fun.(asset_ids)

      {asset_ids, asset_ids}
    end)
  end
end
