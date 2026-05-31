defmodule AssetMonitoringDashWeb.AssetLive.RelatedAssetRanker do
  @moduledoc """
  Ranks assets that are operationally related to the inspected asset.
  """

  def related_assets(asset, all_assets, opts \\ []) do
    limit = Keyword.get(opts, :limit, 4)

    all_assets
    |> Enum.filter(&canonical_asset?/1)
    |> Enum.reject(&(&1.id == asset.id))
    |> Enum.map(&{score(asset, &1), &1})
    |> Enum.reject(fn {score, _asset} -> score == 0 end)
    |> Enum.sort_by(fn {score, related_asset} ->
      {-score, -related_asset.risk_score, related_asset.name}
    end)
    |> Enum.take(limit)
    |> Enum.map(fn {_score, related_asset} -> related_asset end)
  end

  def score(asset, related_asset) do
    chain_match_score(asset, related_asset) +
      ecosystem_match_score(asset, related_asset) +
      risk_band_match_score(asset, related_asset)
  end

  defp canonical_asset?(%{id: id}), do: !String.contains?(id, "-variant-")

  defp chain_match_score(%{chain: chain}, %{chain: chain}), do: 3
  defp chain_match_score(_asset, _related_asset), do: 0

  defp ecosystem_match_score(%{ecosystem: ecosystem}, %{ecosystem: ecosystem}), do: 2
  defp ecosystem_match_score(_asset, _related_asset), do: 0

  defp risk_band_match_score(%{risk_band: risk_band}, %{risk_band: risk_band}), do: 1
  defp risk_band_match_score(_asset, _related_asset), do: 0
end
