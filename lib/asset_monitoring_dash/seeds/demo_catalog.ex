defmodule AssetMonitoringDash.Seeds.DemoCatalog do
  @moduledoc """
  Seeds the local demo catalog used by the asset monitoring dashboard.

  Runtime screens read the seeded records through Ecto contexts. This module is
  the repeatable import boundary for the deterministic local catalog.
  """

  alias AssetMonitoringDash.Assets
  alias AssetMonitoringDash.Assets.Chain
  alias AssetMonitoringDash.Assets.GameEcosystem
  alias AssetMonitoringDash.Assets.MarketSnapshot
  alias AssetMonitoringDash.Assets.MonitoredAsset
  alias AssetMonitoringDash.EventStore
  alias AssetMonitoringDash.Money
  alias AssetMonitoringDash.Repo

  @snapshot_source "seeded_demo_oracle"
  @snapshot_anchor ~U[2026-05-31 00:00:00Z]
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

  def run! do
    assets = Assets.list_assets()

    chains_by_name = seed_chains!(assets)
    ecosystems_by_name = seed_game_ecosystems!(assets)

    Enum.each(assets, &seed_monitored_asset!(&1, chains_by_name, ecosystems_by_name))

    seed_market_snapshots!()
    EventStore.seed_initial_events!()

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

  defp seed_market_snapshots! do
    Repo.delete_all(MarketSnapshot)

    Assets.list_persisted_assets()
    |> Enum.each(&seed_market_snapshots_for_asset!/1)
  end

  defp seed_market_snapshots_for_asset!(asset) do
    asset
    |> market_snapshot_attrs()
    |> Enum.each(fn attrs ->
      %MarketSnapshot{}
      |> MarketSnapshot.changeset(attrs)
      |> Repo.insert!()
    end)
  end

  defp market_snapshot_attrs(asset) do
    asset
    |> ltv_history()
    |> Enum.with_index()
    |> Enum.map(fn {ltv_percent, index} ->
      snapshot_values(asset, ltv_percent, index)
    end)
  end

  defp ltv_history(asset) do
    asset
    |> Map.fetch!(:dom_id)
    |> base_dom_id()
    |> ltv_trend_offsets()
    |> Enum.map(fn offset ->
      asset.ltv_percent
      |> Money.decimal()
      |> Decimal.add(Money.decimal(offset))
      |> Decimal.round(1)
    end)
    |> Kernel.++([asset.ltv_percent])
  end

  defp snapshot_values(asset, ltv_percent, index) do
    observed_at = DateTime.add(@snapshot_anchor, index - 6, :day)
    sequence = snapshot_sequence(asset.dom_id, index)
    current_value_usd = value_for_ltv(asset.loan_value_usd, ltv_percent)
    floor_factor = 0.96 + rem(sequence * 7, 9) / 100
    depth_factor = 0.9 + rem(sequence * 5, 21) / 100

    %{
      asset_id: asset.id,
      current_value_usd: current_value_usd,
      floor_price_usd: asset.floor_price_usd |> Money.multiply(floor_factor) |> Money.max(1),
      loan_value_usd: asset.loan_value_usd,
      ltv_percent: ltv_percent,
      market_depth_usd: asset.market_depth_usd |> Money.multiply(depth_factor) |> Money.max(500),
      observed_at: observed_at,
      oracle_freshness_seconds: snapshot_oracle_freshness(asset, sequence),
      source: @snapshot_source
    }
  end

  defp value_for_ltv(loan_value_usd, ltv_percent) do
    loan_value_usd
    |> Money.decimal()
    |> Decimal.div(Decimal.div(Money.decimal(ltv_percent), 100))
    |> Money.usd()
    |> Money.max(1)
  end

  defp snapshot_sequence(dom_id, index) do
    dom_id
    |> :erlang.phash2(10_000)
    |> Kernel.+(index)
  end

  defp snapshot_oracle_freshness(asset, sequence) do
    freshness_multiplier = 0.65 + rem(sequence * 3, 85) / 100

    asset.oracle_freshness_seconds
    |> Kernel.*(freshness_multiplier)
    |> round()
    |> max(5)
  end

  defp base_dom_id(dom_id) do
    case Regex.run(~r/^(asset-\d{3})/, dom_id) do
      [_full_match, base_id] -> base_id
      _no_match -> dom_id
    end
  end

  defp ltv_trend_offsets(dom_id),
    do: Map.get(@ltv_trend_offsets, dom_id, [-2.0, -1.5, -1.1, -0.7, -0.4, -0.2])

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
