defmodule AssetMonitoringDash.AssetScenarioStore do
  @moduledoc """
  Persistent store for demo asset scenarios.

  Scenario controls are intentionally small, but they still represent operator
  state. Keeping them in the database means the demo can survive process
  restarts and show a real persistence boundary.
  """

  import Ecto.Query

  alias AssetMonitoringDash.Assets
  alias AssetMonitoringDash.AssetScenario
  alias AssetMonitoringDash.Repo

  @price_shock_scenario_id "price_shock"
  @price_shock_drop_percent 12

  @spec shocked_asset_ids() :: MapSet.t(String.t())
  def shocked_asset_ids do
    AssetScenario
    |> where([scenario], scenario.scenario_id == ^@price_shock_scenario_id)
    |> select([scenario], scenario.asset_id)
    |> Repo.all()
    |> MapSet.new()
  end

  @spec apply_price_shock(String.t()) :: MapSet.t(String.t())
  def apply_price_shock(asset_id) do
    asset_id = Assets.resolve_persisted_asset_id(asset_id)

    case Assets.price_drop_projection(asset_id, @price_shock_drop_percent) do
      nil ->
        :ok

      asset ->
        asset
        |> scenario_attrs()
        |> upsert_scenario()
    end

    shocked_asset_ids()
  end

  @spec reset(String.t()) :: MapSet.t(String.t())
  def reset(asset_id) do
    asset_id = Assets.resolve_persisted_asset_id(asset_id)

    AssetScenario
    |> where(
      [scenario],
      scenario.asset_id == ^asset_id and scenario.scenario_id == ^@price_shock_scenario_id
    )
    |> Repo.delete_all()

    shocked_asset_ids()
  end

  @spec reset_all() :: MapSet.t(String.t())
  def reset_all do
    Repo.delete_all(AssetScenario)

    shocked_asset_ids()
  end

  defp scenario_attrs(asset) do
    %{
      applied_at: DateTime.utc_now(:microsecond),
      asset_id: asset.id,
      current_value_usd: asset.current_value_usd,
      drop_percent: @price_shock_drop_percent,
      ltv_percent: asset.ltv_percent,
      risk_band: asset.risk_band,
      risk_score: asset.risk_score,
      scenario_id: @price_shock_scenario_id
    }
  end

  defp upsert_scenario(attrs) do
    %AssetScenario{}
    |> AssetScenario.changeset(attrs)
    |> Repo.insert(
      on_conflict:
        {:replace,
         [
           :applied_at,
           :current_value_usd,
           :drop_percent,
           :ltv_percent,
           :risk_band,
           :risk_score,
           :updated_at
         ]},
      conflict_target: [:asset_id, :scenario_id]
    )
  end
end
