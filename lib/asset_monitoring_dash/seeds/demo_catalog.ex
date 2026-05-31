defmodule AssetMonitoringDash.Seeds.DemoCatalog do
  @moduledoc """
  Seeds the local demo catalog used by the asset monitoring dashboard.

  The application reads this data at runtime, but this module is the only place
  that creates the demo catalog. That keeps persistence setup explicit and easy
  to reset while the schema is still evolving.
  """

  alias AssetMonitoringDash.Assets
  alias AssetMonitoringDash.Assets.Chain
  alias AssetMonitoringDash.Assets.GameEcosystem
  alias AssetMonitoringDash.Assets.MonitoredAsset
  alias AssetMonitoringDash.Repo

  def run! do
    assets = Assets.list_assets()

    chains_by_name = seed_chains!(assets)
    ecosystems_by_name = seed_game_ecosystems!(assets)

    Enum.each(assets, &seed_monitored_asset!(&1, chains_by_name, ecosystems_by_name))

    Assets.list_persisted_assets()
  end

  defp seed_chains!(assets) do
    assets
    |> Enum.map(& &1.chain)
    |> Enum.uniq()
    |> Enum.map(fn name ->
      chain =
        seed_record!(
          Chain,
          [slug: slugify(name)],
          %{
            name: name,
            native_token: native_token_for(name),
            slug: slugify(name)
          }
        )

      {chain.name, chain}
    end)
    |> Map.new()
  end

  defp seed_game_ecosystems!(assets) do
    assets
    |> Enum.map(& &1.ecosystem)
    |> Enum.uniq()
    |> Enum.map(fn name ->
      ecosystem =
        seed_record!(
          GameEcosystem,
          [slug: slugify(name)],
          %{
            genre: genre_for(name),
            name: name,
            slug: slugify(name)
          }
        )

      {ecosystem.name, ecosystem}
    end)
    |> Map.new()
  end

  defp seed_monitored_asset!(asset, chains_by_name, ecosystems_by_name) do
    chain = Map.fetch!(chains_by_name, asset.chain)
    ecosystem = Map.fetch!(ecosystems_by_name, asset.ecosystem)

    seed_record!(
      MonitoredAsset,
      [name: asset.name],
      %{
        asset_type: asset.asset_type,
        chain_id: chain.id,
        current_value_usd: asset.current_value_usd,
        floor_price_usd: asset.floor_price_usd,
        game_ecosystem_id: ecosystem.id,
        icon: asset.icon,
        loan_value_usd: asset.loan_value_usd,
        ltv_percent: asset.ltv_percent,
        market_depth_usd: asset.market_depth_usd,
        name: asset.name,
        oracle_freshness_seconds: asset.oracle_freshness_seconds,
        rarity: asset.rarity,
        risk_band: asset.risk_band,
        risk_score: asset.risk_score
      }
    )
  end

  defp seed_record!(schema_module, lookup, attrs) do
    existing_record = Repo.get_by(schema_module, lookup)
    record = existing_record || struct(schema_module)

    record
    |> schema_module.changeset(attrs)
    |> Repo.insert_or_update!()
  end

  defp native_token_for("Arbitrum"), do: "ETH"
  defp native_token_for("Base"), do: "ETH"
  defp native_token_for("Ethereum"), do: "ETH"
  defp native_token_for("Immutable"), do: "IMX"
  defp native_token_for("Polygon"), do: "POL"
  defp native_token_for("Ronin"), do: "RON"
  defp native_token_for(_chain), do: "ETH"

  defp genre_for("Embervale"), do: "MMO strategy"
  defp genre_for("Mecha Rift"), do: "Tactical battler"
  defp genre_for("Moonwell Tactics"), do: "Guild strategy"
  defp genre_for("Neon Dominion"), do: "Sci-fi economy"
  defp genre_for("Rift Racers"), do: "Racing"
  defp genre_for("Skyforge Arena"), do: "Arena RPG"
  defp genre_for(_ecosystem), do: "Game economy"

  defp slugify(value) do
    value
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
  end
end
