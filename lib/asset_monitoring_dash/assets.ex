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

  def list_assets, do: DemoData.monitored_assets()

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
