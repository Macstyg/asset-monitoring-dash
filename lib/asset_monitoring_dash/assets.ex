defmodule AssetMonitoringDash.Assets do
  @moduledoc """
  Query and filter access for monitored game collateral assets.

  This module is intentionally backed by deterministic demo data for now. It
  gives the product rules a stable home before the data source becomes a repo,
  stream processor, or external integration.
  """

  alias AssetMonitoringDash.DemoData
  alias AssetMonitoringDash.Risk

  @default_filters %{query: "", risk: "All", chain: "All chains"}
  @risk_filter_options [
    {"All risk tiers", "All"},
    {"Low", "Low"},
    {"Moderate", "Moderate"},
    {"Elevated", "Elevated"},
    {"Critical", "Critical"}
  ]
  @at_risk_bands ["Elevated", "Critical"]
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

  def list_assets(filters) do
    filter_assets(list_assets(), filters)
  end

  def filter_assets(assets, filters) do
    assets
    |> filter_assets_by_query(filters.query)
    |> filter_assets_by_risk(filters.risk)
    |> filter_assets_by_chain(filters.chain)
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
      risk: normalize_risk_filter(Map.get(params, "risk", current_filters.risk)),
      chain: normalize_chain_filter(Map.get(params, "chain", current_filters.chain))
    }
  end

  def risk_filter_options, do: @risk_filter_options

  def chain_filter_options do
    chains =
      list_assets()
      |> Enum.map(& &1.chain)
      |> Enum.uniq()
      |> Enum.sort()

    [{"All chains", "All chains"} | Enum.map(chains, &{&1, &1})]
  end

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

  defp filter_assets_by_risk(assets, "All"), do: assets

  defp filter_assets_by_risk(assets, risk_filter),
    do: Enum.filter(assets, &(&1.risk_band == risk_filter))

  defp filter_assets_by_chain(assets, "All chains"), do: assets

  defp filter_assets_by_chain(assets, chain_filter),
    do: Enum.filter(assets, &(&1.chain == chain_filter))

  defp normalize_query(nil), do: ""

  defp normalize_query(query) do
    query
    |> String.trim()
    |> String.downcase()
  end

  defp normalize_risk_filter(risk)
       when risk in ["All", "Low", "Moderate", "Elevated", "Critical"],
       do: risk

  defp normalize_risk_filter(_risk), do: "All"

  defp normalize_chain_filter("All chains"), do: "All chains"

  defp normalize_chain_filter(chain) do
    list_assets()
    |> Enum.map(& &1.chain)
    |> Enum.find(&(&1 == chain))
    |> normalize_chain_filter_value()
  end

  defp normalize_chain_filter_value(nil), do: "All chains"
  defp normalize_chain_filter_value(chain), do: chain

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

    %{
      asset
      | ltv_percent: ltv_percent,
        risk_score: risk_score,
        risk_band: Risk.risk_band(risk_score)
    }
  end

  defp apply_asset_price_drop(%{id: asset_id} = asset, asset_id, drop_percent) do
    value_multiplier = 1 - drop_percent / 100
    current_value_usd = round(asset.current_value_usd * value_multiplier)
    repriced_asset = %{asset | current_value_usd: current_value_usd}
    ltv_percent = Float.round(Risk.ltv_percent(repriced_asset), 1)
    risk_score = Risk.risk_score(repriced_asset)

    %{
      repriced_asset
      | ltv_percent: ltv_percent,
        risk_score: risk_score,
        risk_band: Risk.risk_band(risk_score)
    }
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
