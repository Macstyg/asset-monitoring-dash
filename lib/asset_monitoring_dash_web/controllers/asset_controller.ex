defmodule AssetMonitoringDashWeb.AssetController do
  use AssetMonitoringDashWeb, :controller

  alias AssetMonitoringDash.Assets

  def index(conn, params) do
    filters = asset_filters(params)
    assets = Assets.list_assets(filters)

    json(conn, %{
      data: Enum.map(assets, &asset_json/1),
      meta: %{
        count: length(assets),
        filters: filters,
        summary: Assets.summarize_assets(assets)
      }
    })
  end

  defp asset_filters(params) do
    params
    |> Map.put_new("risk", Map.get(params, "risk_band"))
    |> Assets.normalize_filters(Assets.default_filters())
  end

  defp asset_json(asset) do
    %{
      id: asset.id,
      name: asset.name,
      asset_type: asset.asset_type,
      chain: asset.chain,
      ecosystem: asset.ecosystem,
      rarity: asset.rarity,
      floor_price_usd: asset.floor_price_usd,
      current_value_usd: asset.current_value_usd,
      loan_value_usd: asset.loan_value_usd,
      ltv_percent: asset.ltv_percent,
      risk_score: asset.risk_score,
      risk_band: asset.risk_band
    }
  end
end
