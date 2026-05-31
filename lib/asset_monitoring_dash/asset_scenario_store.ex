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
  alias AssetMonitoringDash.Money
  alias AssetMonitoringDash.Repo
  alias AssetMonitoringDash.Risk

  @price_shock_scenario_id "price_shock"
  @price_shock_drop_percent 12
  @scenario_options [
    %{
      id: "price_shock",
      label: "Price shock",
      short_label: "Price",
      description: "Reprices collateral lower and raises LTV pressure.",
      tone: :warning
    },
    %{
      id: "oracle_stale",
      label: "Oracle stale",
      short_label: "Oracle",
      description: "Forces price-feed freshness outside the trusted window.",
      tone: :danger
    },
    %{
      id: "liquidity_thinning",
      label: "Liquidity thinning",
      short_label: "Liquidity",
      description: "Cuts available market depth and weakens exit confidence.",
      tone: :warning
    },
    %{
      id: "borrower_top_up",
      label: "Borrower top-up",
      short_label: "Top-up",
      description: "Adds collateral value and improves the health buffer.",
      tone: :success
    },
    %{
      id: "repayment",
      label: "Repayment",
      short_label: "Repayment",
      description: "Reduces borrowed value and lowers LTV.",
      tone: :success
    }
  ]

  def price_shock_drop_percent, do: @price_shock_drop_percent
  def scenario_options, do: @scenario_options
  def scenario_ids, do: Enum.map(@scenario_options, & &1.id)

  @spec shocked_asset_ids() :: MapSet.t(String.t())
  def shocked_asset_ids, do: active_asset_ids()

  @spec active_asset_ids() :: MapSet.t(String.t())
  def active_asset_ids do
    AssetScenario
    |> select([scenario], scenario.asset_id)
    |> Repo.all()
    |> MapSet.new()
  end

  def active_summary do
    counts_by_scenario_id =
      AssetScenario
      |> group_by([scenario], scenario.scenario_id)
      |> select([scenario], {scenario.scenario_id, count(scenario.id)})
      |> Repo.all()
      |> Map.new()

    @scenario_options
    |> Enum.map(&Map.put(&1, :count, Map.get(counts_by_scenario_id, &1.id, 0)))
    |> Enum.filter(&(&1.count > 0))
  end

  def scenario_option_for(scenario_id) do
    Enum.find(@scenario_options, &(&1.id == scenario_id))
  end

  def scenario_option_for_asset(asset_id) do
    asset_id = Assets.resolve_persisted_asset_id(asset_id)

    AssetScenario
    |> where([scenario], scenario.asset_id == ^asset_id)
    |> order_by([scenario], desc: scenario.applied_at)
    |> limit(1)
    |> Repo.one()
    |> scenario_option_for_record()
  end

  @spec apply_price_shock(String.t()) :: MapSet.t(String.t())
  def apply_price_shock(asset_id) do
    apply_scenario(asset_id, @price_shock_scenario_id)
  end

  @spec apply_scenario(String.t(), String.t()) :: MapSet.t(String.t())
  def apply_scenario(asset_id, scenario_id)
      when scenario_id in [
             "price_shock",
             "oracle_stale",
             "liquidity_thinning",
             "borrower_top_up",
             "repayment"
           ] do
    asset_id = Assets.resolve_persisted_asset_id(asset_id)

    case scenario_projection(asset_id, scenario_id) do
      nil ->
        :ok

      asset ->
        delete_asset_scenarios(asset_id)

        asset
        |> scenario_attrs(scenario_id)
        |> upsert_scenario()
    end

    active_asset_ids()
  end

  def apply_scenario(asset_id, _scenario_id), do: active_asset_ids_for_unchanged_asset(asset_id)

  @spec reset(String.t()) :: MapSet.t(String.t())
  def reset(asset_id) do
    asset_id = Assets.resolve_persisted_asset_id(asset_id)

    delete_asset_scenarios(asset_id)

    active_asset_ids()
  end

  @spec reset_all() :: MapSet.t(String.t())
  def reset_all do
    Repo.delete_all(AssetScenario)

    active_asset_ids()
  end

  defp scenario_option_for_record(nil), do: nil

  defp scenario_option_for_record(%{scenario_id: scenario_id}),
    do: scenario_option_for(scenario_id)

  defp scenario_projection(asset_id, "price_shock") do
    Assets.price_drop_projection(asset_id, @price_shock_drop_percent)
  end

  defp scenario_projection(asset_id, scenario_id) do
    case Assets.get_persisted_asset(asset_id) do
      nil -> nil
      asset -> project_asset(asset, scenario_id)
    end
  end

  defp project_asset(asset, "oracle_stale") do
    asset
    |> Map.put(:oracle_freshness_seconds, max(asset.oracle_freshness_seconds, 720))
    |> recalculate_projection()
  end

  defp project_asset(asset, "liquidity_thinning") do
    asset
    |> Map.put(:market_depth_usd, Money.multiply(asset.market_depth_usd, 0.18))
    |> recalculate_projection()
  end

  defp project_asset(asset, "borrower_top_up") do
    asset
    |> Map.put(:current_value_usd, Money.multiply(asset.current_value_usd, 1.16))
    |> recalculate_projection()
  end

  defp project_asset(asset, "repayment") do
    asset
    |> Map.put(:loan_value_usd, Money.multiply(asset.loan_value_usd, 0.82))
    |> recalculate_projection()
  end

  defp recalculate_projection(asset) do
    ltv_percent = Risk.ltv_percent(asset)
    risk_score = Risk.risk_score(%{asset | ltv_percent: ltv_percent})

    %{
      asset
      | ltv_percent: ltv_percent,
        risk_score: risk_score,
        risk_band: Risk.risk_band(risk_score)
    }
  end

  defp scenario_attrs(asset, scenario_id) do
    %{
      applied_at: DateTime.utc_now(:microsecond),
      asset_id: asset.id,
      current_value_usd: asset.current_value_usd,
      drop_percent: drop_percent(scenario_id),
      loan_value_usd: asset.loan_value_usd,
      ltv_percent: asset.ltv_percent,
      market_depth_usd: asset.market_depth_usd,
      oracle_freshness_seconds: asset.oracle_freshness_seconds,
      risk_band: asset.risk_band,
      risk_score: asset.risk_score,
      scenario_id: scenario_id
    }
  end

  defp drop_percent("price_shock"), do: @price_shock_drop_percent
  defp drop_percent(_scenario_id), do: 0

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
           :loan_value_usd,
           :ltv_percent,
           :market_depth_usd,
           :oracle_freshness_seconds,
           :risk_band,
           :risk_score,
           :updated_at
         ]},
      conflict_target: [:asset_id, :scenario_id]
    )
  end

  defp delete_asset_scenarios(asset_id) do
    AssetScenario
    |> where([scenario], scenario.asset_id == ^asset_id)
    |> Repo.delete_all()
  end

  defp active_asset_ids_for_unchanged_asset(_asset_id), do: active_asset_ids()
end
