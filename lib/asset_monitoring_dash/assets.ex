defmodule AssetMonitoringDash.Assets do
  @moduledoc """
  Query and filter access for monitored game collateral assets.

  This module is intentionally backed by deterministic demo data for now. It
  gives the product rules a stable home before the data source becomes a repo,
  stream processor, or external integration.
  """

  alias AssetMonitoringDash.DemoData
  alias AssetMonitoringDash.ReviewState
  alias AssetMonitoringDash.Risk
  alias AssetMonitoringDash.RiskRecommendation

  @default_filters %{
    query: "",
    risks: [],
    chains: [],
    actions: [],
    operator_states: [],
    risk_option_query: "",
    chain_option_query: "",
    action_option_query: "",
    operator_state_option_query: ""
  }
  @risk_filter_options [
    %{label: "Low", value: "Low", icon_text: "L", tone: :success},
    %{label: "Moderate", value: "Moderate", icon_text: "M", tone: :info},
    %{label: "Elevated", value: "Elevated", icon_text: "E", tone: :warning},
    %{label: "Critical", value: "Critical", icon_text: "C", tone: :danger}
  ]
  @action_filter_options [
    %{label: "Manual review", value: "manual_review", icon_text: "M", tone: :warning},
    %{
      label: "Liquidation candidate",
      value: "liquidation_candidate",
      icon_text: "L",
      tone: :danger
    },
    %{label: "Watch", value: "watch", icon_text: "W", tone: :info},
    %{label: "Clear", value: "clear", icon_text: "C", tone: :success}
  ]
  @operator_state_filter_options [
    %{label: "Unreviewed", value: "unreviewed", icon_text: "U", tone: :neutral},
    %{label: "Reviewed", value: "reviewed", icon_text: "R", tone: :success},
    %{label: "Escalated", value: "escalated", icon_text: "E", tone: :warning}
  ]
  @at_risk_bands ["Elevated", "Critical"]
  @fresh_oracle_max_seconds 60
  @delayed_oracle_max_seconds 300
  @deep_market_depth_min_usd 25_000
  @thin_market_depth_min_usd 5_000
  @ltv_trend_offsets %{
    "asset-001" => [-3.2, -2.4, -1.9, -1.1, -0.8, -0.3],
    "asset-002" => [-1.0, 0.7, -0.2, 1.6, 2.1, 1.2],
    "asset-003" => [2.4, 1.8, 1.1, 0.5, -0.1, -0.4],
    "asset-004" => [0.4, -0.7, -1.4, -0.9, -1.7, -2.1],
    "asset-005" => [-4.8, -2.9, -3.7, -1.8, -2.4, -0.9],
    "asset-006" => [-0.4, 0.2, -0.2, 0.1, -0.1, 0.3],
    "asset-007" => [1.8, 0.9, 1.3, 2.6, 1.7, 0.8],
    "asset-008" => [-1.8, -0.6, 0.4, -0.2, 0.8, 1.5],
    "asset-009" => [3.7, 2.6, 1.9, 1.1, 0.4, -0.2],
    "asset-010" => [-5.6, -3.1, -4.4, -1.7, 0.9, 2.8],
    "asset-011" => [0.6, 0.4, 0.3, 0.1, -0.2, -0.3],
    "asset-012" => [-0.9, -1.5, -0.4, 0.6, -0.1, 0.9]
  }

  def list_assets do
    Enum.map(DemoData.monitored_assets(), &normalize_risk_fields/1)
  end

  def list_assets(filters, review_states \\ %{}) do
    filter_assets(list_assets(), filters, review_states)
  end

  def filter_assets(assets, filters, review_states \\ %{}) do
    assets
    |> filter_assets_by_query(filter_value(filters, :query, ""))
    |> filter_assets_by_risks(filter_values(filters, :risks, :risk, "All"))
    |> filter_assets_by_chains(filter_values(filters, :chains, :chain, "All chains"))
    |> filter_assets_by_actions(filter_values(filters, :actions, :action, "All"))
    |> filter_assets_by_operator_states(
      filter_values(filters, :operator_states, :operator_state, "All"),
      review_states
    )
  end

  def get_asset(asset_id) do
    Enum.find(list_assets(), &(&1.id == asset_id))
  end

  def get_asset(assets, asset_id) do
    Enum.find(assets, &(&1.id == asset_id))
  end

  def apply_price_drop(assets, asset_id, drop_percent) do
    Enum.map(assets, &apply_asset_price_drop(&1, asset_id, drop_percent))
  end

  def reset_asset(assets, asset_id) do
    original_asset = get_asset(asset_id)

    Enum.map(assets, &reset_asset_value(&1, asset_id, original_asset))
  end

  def ltv_trend(asset) do
    baseline_asset = get_asset(asset.id) || asset
    baseline_ltv = baseline_asset.ltv_percent

    baseline_asset.id
    |> ltv_trend_offsets()
    |> Enum.zip(["6d", "5d", "4d", "3d", "2d", "1d"])
    |> Enum.map(fn {offset, label} -> trend_point(label, baseline_ltv + offset) end)
    |> Kernel.++([trend_point("Now", asset.ltv_percent)])
  end

  def summarize_assets(assets) do
    %{
      visible_count: length(assets),
      total_value_usd: total_value_usd(assets),
      at_risk_count: at_risk_count(assets),
      average_ltv_percent: average_ltv_percent(assets),
      highest_ltv_percent: highest_ltv_percent(assets)
    }
  end

  def default_filters, do: @default_filters

  def normalize_filters(params, current_filters) do
    %{
      query: normalize_query(Map.get(params, "query", current_filters.query)),
      risks:
        normalize_filter_values(
          params,
          "risks",
          "risk",
          current_filter_values(current_filters, :risks, :risk, "All"),
          filter_option_values(@risk_filter_options)
        ),
      chains:
        normalize_filter_values(
          params,
          "chains",
          "chain",
          current_filter_values(current_filters, :chains, :chain, "All chains"),
          chain_filter_values()
        ),
      actions:
        normalize_filter_values(
          params,
          "actions",
          "action",
          current_filter_values(current_filters, :actions, :action, "All"),
          filter_option_values(@action_filter_options)
        ),
      operator_states:
        normalize_filter_values(
          params,
          "operator_states",
          "operator_state",
          current_filter_values(current_filters, :operator_states, :operator_state, "All"),
          filter_option_values(@operator_state_filter_options)
        ),
      risk_option_query: normalize_query(Map.get(params, "risk_option_query", "")),
      chain_option_query: normalize_query(Map.get(params, "chain_option_query", "")),
      action_option_query: normalize_query(Map.get(params, "action_option_query", "")),
      operator_state_option_query:
        normalize_query(Map.get(params, "operator_state_option_query", ""))
    }
  end

  def risk_filter_options, do: @risk_filter_options
  def action_filter_options, do: @action_filter_options
  def operator_state_filter_options, do: @operator_state_filter_options

  def chain_filter_options do
    chains =
      list_assets()
      |> Enum.map(& &1.chain)
      |> Enum.uniq()
      |> Enum.sort()

    Enum.map(chains, &%{label: &1, value: &1, icon: :chain})
  end

  def filter_options(options, ""), do: options

  def filter_options(options, query) do
    Enum.filter(options, fn option ->
      option
      |> Map.fetch!(:label)
      |> String.downcase()
      |> String.contains?(query)
    end)
  end

  def oracle_status(freshness_seconds) when freshness_seconds <= @fresh_oracle_max_seconds,
    do: "Fresh"

  def oracle_status(freshness_seconds) when freshness_seconds <= @delayed_oracle_max_seconds,
    do: "Delayed"

  def oracle_status(_freshness_seconds), do: "Stale"

  def liquidity_status(market_depth_usd) when market_depth_usd >= @deep_market_depth_min_usd,
    do: "Deep"

  def liquidity_status(market_depth_usd) when market_depth_usd >= @thin_market_depth_min_usd,
    do: "Thin"

  def liquidity_status(_market_depth_usd), do: "Illiquid"

  defp filter_assets_by_query(assets, ""), do: assets

  defp filter_assets_by_query(assets, query) do
    Enum.filter(assets, &asset_matches_query?(&1, query))
  end

  defp asset_matches_query?(asset, query) do
    [
      asset.name,
      asset.asset_type,
      asset.chain,
      asset.ecosystem,
      asset.rarity,
      asset.risk_band
    ]
    |> Enum.any?(&String.contains?(String.downcase(&1), query))
  end

  defp filter_assets_by_risks(assets, []), do: assets

  defp filter_assets_by_risks(assets, risk_filters),
    do: Enum.filter(assets, &(&1.risk_band in risk_filters))

  defp filter_assets_by_chains(assets, []), do: assets

  defp filter_assets_by_chains(assets, chain_filters),
    do: Enum.filter(assets, &(&1.chain in chain_filters))

  defp filter_assets_by_actions(assets, []), do: assets

  defp filter_assets_by_actions(assets, action_filters) do
    Enum.filter(assets, fn asset ->
      asset
      |> RiskRecommendation.recommendation_for()
      |> Map.fetch!(:id)
      |> Atom.to_string()
      |> then(&(&1 in action_filters))
    end)
  end

  defp filter_assets_by_operator_states(assets, [], _review_states), do: assets

  defp filter_assets_by_operator_states(assets, operator_state_filters, review_states) do
    Enum.filter(assets, fn asset ->
      asset.id
      |> ReviewState.state_for(review_states)
      |> Map.fetch!(:id)
      |> Atom.to_string()
      |> then(&(&1 in operator_state_filters))
    end)
  end

  defp normalize_query(nil), do: ""

  defp normalize_query(query) do
    query
    |> String.trim()
    |> String.downcase()
  end

  defp normalize_filter_values(params, list_key, legacy_key, current_values, allowed_values) do
    params
    |> filter_param_values(list_key, legacy_key, current_values)
    |> Enum.reject(&(&1 in [nil, "", "All", "All chains"]))
    |> Enum.filter(&(&1 in allowed_values))
    |> Enum.uniq()
  end

  defp filter_param_values(params, list_key, legacy_key, current_values) do
    cond do
      Map.has_key?(params, list_key) -> List.wrap(Map.get(params, list_key))
      Map.has_key?(params, legacy_key) -> List.wrap(Map.get(params, legacy_key))
      true -> current_values
    end
  end

  defp current_filter_values(filters, list_key, legacy_key, all_value) do
    filters
    |> Map.get(list_key, legacy_filter_values(Map.get(filters, legacy_key, all_value), all_value))
    |> List.wrap()
  end

  defp legacy_filter_values(value, all_value) when value in [nil, "", all_value], do: []
  defp legacy_filter_values(value, _all_value), do: [value]

  defp filter_values(filters, list_key, legacy_key, all_value) do
    filters
    |> Map.get(list_key, legacy_filter_values(Map.get(filters, legacy_key, all_value), all_value))
    |> List.wrap()
    |> Enum.reject(&(&1 in [nil, "", all_value]))
  end

  defp filter_value(filters, key, default), do: Map.get(filters, key, default)

  defp filter_option_values(options), do: Enum.map(options, & &1.value)

  defp chain_filter_values do
    chain_filter_options()
    |> filter_option_values()
  end

  defp ltv_trend_offsets(asset_id) do
    Map.get(@ltv_trend_offsets, asset_id, [-2.0, -1.5, -1.1, -0.7, -0.4, -0.2])
  end

  defp trend_point(label, value) do
    %{label: label, value: value |> clamp_ltv() |> Float.round(1)}
  end

  defp clamp_ltv(value) when value < 0.0, do: 0.0
  defp clamp_ltv(value) when value > 100.0, do: 100.0
  defp clamp_ltv(value), do: value

  defp normalize_risk_fields(asset) do
    ltv_percent = Float.round(Risk.ltv_percent(asset), 1)
    risk_score = Risk.risk_score(%{asset | ltv_percent: ltv_percent})

    asset
    |> Map.merge(%{
      ltv_percent: ltv_percent,
      risk_score: risk_score,
      risk_band: Risk.risk_band(risk_score)
    })
    |> Map.put(:oracle_status, oracle_status(asset.oracle_freshness_seconds))
    |> Map.put(:liquidity_status, liquidity_status(asset.market_depth_usd))
  end

  defp apply_asset_price_drop(%{id: asset_id} = asset, asset_id, drop_percent) do
    value_multiplier = 1 - drop_percent / 100
    current_value_usd = round(asset.current_value_usd * value_multiplier)
    repriced_asset = %{asset | current_value_usd: current_value_usd}
    ltv_percent = Float.round(Risk.ltv_percent(repriced_asset), 1)
    risk_score = Risk.risk_score(repriced_asset)

    repriced_asset
    |> Map.merge(%{
      ltv_percent: ltv_percent,
      risk_score: risk_score,
      risk_band: Risk.risk_band(risk_score)
    })
    |> Map.put(:oracle_status, oracle_status(repriced_asset.oracle_freshness_seconds))
    |> Map.put(:liquidity_status, liquidity_status(repriced_asset.market_depth_usd))
  end

  defp apply_asset_price_drop(asset, _asset_id, _drop_percent), do: asset

  defp reset_asset_value(%{id: asset_id} = asset, asset_id, nil), do: asset
  defp reset_asset_value(%{id: asset_id}, asset_id, original_asset), do: original_asset
  defp reset_asset_value(asset, _asset_id, _original_asset), do: asset

  defp total_value_usd(assets) do
    Enum.sum(Enum.map(assets, & &1.current_value_usd))
  end

  defp at_risk_count(assets) do
    Enum.count(assets, &(&1.risk_band in @at_risk_bands))
  end

  defp average_ltv_percent([]), do: 0.0

  defp average_ltv_percent(assets) do
    assets
    |> Enum.map(& &1.ltv_percent)
    |> Enum.sum()
    |> Kernel./(length(assets))
  end

  defp highest_ltv_percent([]), do: 0.0

  defp highest_ltv_percent(assets) do
    assets
    |> Enum.map(& &1.ltv_percent)
    |> Enum.max()
  end
end
