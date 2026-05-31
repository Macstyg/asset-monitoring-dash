defmodule AssetMonitoringDash.Assets do
  @moduledoc """
  Query and filter access for monitored game collateral assets.

  This module is intentionally backed by deterministic demo data for now. It
  gives the product rules a stable home before the data source becomes a repo,
  stream processor, or external integration.
  """

  import Ecto.Query

  alias AssetMonitoringDash.Assets.Chain
  alias AssetMonitoringDash.Assets.GameEcosystem
  alias AssetMonitoringDash.Assets.MonitoredAsset
  alias AssetMonitoringDash.DemoData
  alias AssetMonitoringDash.Repo
  alias AssetMonitoringDash.ReviewState
  alias AssetMonitoringDash.Risk
  alias AssetMonitoringDash.RiskRecommendation

  @variant_count_per_asset 49
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
    canonical_assets = canonical_assets()

    canonical_assets ++ generated_variant_assets(canonical_assets)
  end

  def persist_demo_catalog! do
    assets = list_assets()
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    persist_chains!(assets, now)
    persist_game_ecosystems!(assets, now)

    chains_by_name = persisted_chains_by_name()
    ecosystems_by_name = persisted_game_ecosystems_by_name()

    assets
    |> Enum.map(&monitored_asset_attrs(&1, chains_by_name, ecosystems_by_name, now))
    |> persist_monitored_assets!()

    list_persisted_assets()
  end

  def persisted_asset_count do
    Repo.aggregate(MonitoredAsset, :count)
  end

  def catalog_seeded? do
    persisted_asset_count() >= length(list_assets())
  end

  def ensure_demo_catalog! do
    case catalog_seeded?() do
      true -> :ok
      false -> persist_demo_catalog!()
    end
  end

  def list_persisted_assets do
    MonitoredAsset
    |> order_by([asset], asc: asset.public_id)
    |> preload([:chain, :game_ecosystem])
    |> Repo.all()
    |> Enum.map(&persisted_asset_to_map/1)
  end

  def list_persisted_assets_with_scenarios(shocked_asset_ids) do
    list_persisted_assets()
    |> apply_scenarios(shocked_asset_ids)
  end

  def list_persisted_assets_page(opts) do
    filters = Map.fetch!(opts, :filters)
    sort = Map.fetch!(opts, :sort)
    cursor = Map.get(opts, :cursor)
    limit = Map.get(opts, :limit, 50)
    review_states = Map.get(opts, :review_states, %{})
    shocked_asset_ids = Map.get(opts, :shocked_asset_ids, MapSet.new())

    assets =
      filters
      |> persisted_asset_query()
      |> Repo.all()
      |> Enum.map(&persisted_asset_to_map/1)
      |> apply_scenarios(shocked_asset_ids)
      |> filter_assets_by_actions(filter_values(filters, :actions, :action, "All"))
      |> filter_assets_by_operator_states(
        filter_values(filters, :operator_states, :operator_state, "All"),
        review_states
      )
      |> sort_assets(sort, review_states)

    offset = cursor_to_offset(cursor)
    entries = Enum.slice(assets, offset, limit)
    next_offset = offset + length(entries)

    %{
      entries: entries,
      next_cursor: next_cursor(next_offset, length(assets)),
      total_count: length(assets),
      summary: summarize_assets(assets)
    }
  end

  def list_assets_with_scenarios(shocked_asset_ids) do
    shocked_asset_ids
    |> Enum.reduce(list_assets(), &apply_price_drop(&2, &1, 12))
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

  def list_assets_page(opts) do
    filters = Map.fetch!(opts, :filters)
    sort = Map.fetch!(opts, :sort)
    cursor = Map.get(opts, :cursor)
    limit = Map.get(opts, :limit, 50)
    review_states = Map.get(opts, :review_states, %{})
    shocked_asset_ids = Map.get(opts, :shocked_asset_ids, MapSet.new())

    assets =
      shocked_asset_ids
      |> list_assets_with_scenarios()
      |> filter_assets(filters, review_states)
      |> sort_assets(sort, review_states)

    offset = cursor_to_offset(cursor)
    entries = Enum.slice(assets, offset, limit)
    next_offset = offset + length(entries)

    %{
      entries: entries,
      next_cursor: next_cursor(next_offset, length(assets)),
      total_count: length(assets),
      summary: summarize_assets(assets)
    }
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
    |> expand_filter_values()
    |> Enum.reject(&(&1 in [nil, "", "All", "All chains"]))
    |> Enum.filter(&(&1 in allowed_values))
    |> Enum.uniq()
  end

  defp expand_filter_values(values) do
    values
    |> List.wrap()
    |> Enum.flat_map(&expand_filter_value/1)
  end

  defp expand_filter_value(value) when is_binary(value) do
    value
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
  end

  defp expand_filter_value(value), do: [value]

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

  defp canonical_assets do
    Enum.map(DemoData.monitored_assets(), &normalize_risk_fields/1)
  end

  defp persist_chains!(assets, now) do
    assets
    |> Enum.map(& &1.chain)
    |> Enum.uniq()
    |> Enum.map(fn name ->
      %{
        inserted_at: now,
        name: name,
        native_token: native_token_for(name),
        slug: slugify(name),
        updated_at: now
      }
    end)
    |> then(fn rows ->
      Repo.insert_all(Chain, rows,
        conflict_target: :slug,
        on_conflict: {:replace, [:name, :native_token, :updated_at]}
      )
    end)
  end

  defp persist_game_ecosystems!(assets, now) do
    assets
    |> Enum.map(& &1.ecosystem)
    |> Enum.uniq()
    |> Enum.map(fn name ->
      %{
        genre: genre_for(name),
        inserted_at: now,
        name: name,
        slug: slugify(name),
        updated_at: now
      }
    end)
    |> then(fn rows ->
      Repo.insert_all(GameEcosystem, rows,
        conflict_target: :slug,
        on_conflict: {:replace, [:name, :genre, :updated_at]}
      )
    end)
  end

  defp persisted_chains_by_name do
    Chain
    |> Repo.all()
    |> Map.new(&{&1.name, &1})
  end

  defp persisted_game_ecosystems_by_name do
    GameEcosystem
    |> Repo.all()
    |> Map.new(&{&1.name, &1})
  end

  defp persist_monitored_assets!(rows) do
    Repo.insert_all(MonitoredAsset, rows,
      conflict_target: :public_id,
      on_conflict:
        {:replace,
         [
           :asset_type,
           :chain_id,
           :current_value_usd,
           :floor_price_usd,
           :game_ecosystem_id,
           :icon,
           :loan_value_usd,
           :ltv_percent,
           :market_depth_usd,
           :name,
           :oracle_freshness_seconds,
           :rarity,
           :risk_band,
           :risk_score,
           :updated_at
         ]}
    )
  end

  defp monitored_asset_attrs(asset, chains_by_name, ecosystems_by_name, now) do
    chain = Map.fetch!(chains_by_name, asset.chain)
    ecosystem = Map.fetch!(ecosystems_by_name, asset.ecosystem)

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
      public_id: asset.id,
      rarity: asset.rarity,
      risk_band: asset.risk_band,
      risk_score: asset.risk_score,
      inserted_at: now,
      updated_at: now
    }
  end

  defp persisted_asset_to_map(asset) do
    %{
      id: asset.public_id,
      name: asset.name,
      icon: asset.icon,
      asset_type: asset.asset_type,
      chain: asset.chain.name,
      ecosystem: asset.game_ecosystem.name,
      rarity: asset.rarity,
      floor_price_usd: asset.floor_price_usd,
      current_value_usd: asset.current_value_usd,
      loan_value_usd: asset.loan_value_usd,
      ltv_percent: asset.ltv_percent,
      risk_score: asset.risk_score,
      risk_band: asset.risk_band,
      oracle_freshness_seconds: asset.oracle_freshness_seconds,
      market_depth_usd: asset.market_depth_usd
    }
    |> normalize_risk_fields()
  end

  defp persisted_asset_query(filters) do
    MonitoredAsset
    |> join(:inner, [asset], chain in assoc(asset, :chain), as: :chain)
    |> join(:inner, [asset], game_ecosystem in assoc(asset, :game_ecosystem), as: :game_ecosystem)
    |> preload([chain: chain, game_ecosystem: game_ecosystem],
      chain: chain,
      game_ecosystem: game_ecosystem
    )
    |> filter_persisted_assets_by_query(filter_value(filters, :query, ""))
    |> filter_persisted_assets_by_risks(filter_values(filters, :risks, :risk, "All"))
    |> filter_persisted_assets_by_chains(filter_values(filters, :chains, :chain, "All chains"))
    |> order_by([asset], asc: asset.public_id)
  end

  defp filter_persisted_assets_by_query(query, ""), do: query

  defp filter_persisted_assets_by_query(query, search_query) do
    search_pattern = "%#{search_query}%"

    where(
      query,
      [asset, chain: chain, game_ecosystem: game_ecosystem],
      ilike(asset.name, ^search_pattern) or
        ilike(asset.asset_type, ^search_pattern) or
        ilike(asset.rarity, ^search_pattern) or
        ilike(asset.risk_band, ^search_pattern) or
        ilike(chain.name, ^search_pattern) or
        ilike(game_ecosystem.name, ^search_pattern)
    )
  end

  defp filter_persisted_assets_by_risks(query, []), do: query

  defp filter_persisted_assets_by_risks(query, risk_filters) do
    where(query, [asset], asset.risk_band in ^risk_filters)
  end

  defp filter_persisted_assets_by_chains(query, []), do: query

  defp filter_persisted_assets_by_chains(query, chain_filters) do
    where(query, [chain: chain], chain.name in ^chain_filters)
  end

  defp apply_scenarios(assets, shocked_asset_ids) do
    Enum.reduce(shocked_asset_ids, assets, &apply_price_drop(&2, &1, 12))
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

  defp generated_variant_assets(canonical_assets) do
    for {asset, asset_index} <- Enum.with_index(canonical_assets),
        variant_index <- 1..@variant_count_per_asset do
      asset
      |> variant_asset(asset_index, variant_index)
      |> normalize_risk_fields()
    end
  end

  defp variant_asset(asset, asset_index, variant_index) do
    sequence = asset_index * @variant_count_per_asset + variant_index
    suffix = variant_suffix(variant_index)
    current_factor = 0.86 + rem(sequence * 7, 29) / 100
    ltv_factor = 0.72 + rem(sequence * 5, 24) / 100
    floor_factor = current_factor * (0.92 + rem(sequence * 11, 17) / 100)
    depth_factor = 0.35 + rem(sequence * 13, 170) / 100

    %{
      asset
      | id: "#{asset.id}-variant-#{suffix}",
        name: "#{asset.name} V#{suffix}",
        floor_price_usd: asset.floor_price_usd |> Kernel.*(floor_factor) |> round() |> max(1),
        current_value_usd:
          asset.current_value_usd |> Kernel.*(current_factor) |> round() |> max(1),
        loan_value_usd:
          asset.loan_value_usd
          |> Kernel.*(current_factor * ltv_factor)
          |> round()
          |> max(1),
        oracle_freshness_seconds: variant_oracle_freshness(sequence),
        market_depth_usd: asset.market_depth_usd |> Kernel.*(depth_factor) |> round() |> max(500)
    }
  end

  defp variant_suffix(variant_index) do
    variant_index
    |> Integer.to_string()
    |> String.pad_leading(3, "0")
  end

  defp variant_oracle_freshness(sequence) do
    Enum.at([18, 24, 36, 58, 92, 184, 216, 420, 620, 760], rem(sequence, 10))
  end

  defp sort_assets(assets, sort, review_states) do
    Enum.sort(assets, &asset_before?(&1, &2, sort, review_states))
  end

  defp asset_before?(asset, other_asset, %{field: field, direction: direction}, review_states) do
    asset_value = sort_value(asset, field, review_states)
    other_value = sort_value(other_asset, field, review_states)

    case compare_sort_values(asset_value, other_value, direction) do
      :before -> true
      :after -> false
      :same -> asset.id <= other_asset.id
    end
  end

  defp compare_sort_values(value, value, _direction), do: :same
  defp compare_sort_values(value, other_value, :asc) when value < other_value, do: :before
  defp compare_sort_values(_value, _other_value, :asc), do: :after
  defp compare_sort_values(value, other_value, :desc) when value > other_value, do: :before
  defp compare_sort_values(_value, _other_value, :desc), do: :after

  defp sort_value(asset, :asset, _review_states), do: String.downcase(asset.name)

  defp sort_value(asset, :chain, _review_states),
    do: String.downcase("#{asset.chain} #{asset.ecosystem}")

  defp sort_value(asset, :floor, _review_states), do: asset.floor_price_usd
  defp sort_value(asset, :value, _review_states), do: asset.current_value_usd
  defp sort_value(asset, :ltv, _review_states), do: asset.ltv_percent
  defp sort_value(asset, :risk, _review_states), do: risk_sort_rank(asset.risk_band)

  defp sort_value(asset, :operator, review_states) do
    asset.id
    |> ReviewState.state_for(review_states)
    |> Map.fetch!(:id)
    |> operator_sort_rank()
  end

  defp sort_value(asset, :action, _review_states) do
    asset
    |> RiskRecommendation.recommendation_for()
    |> Map.fetch!(:id)
    |> action_sort_rank()
  end

  defp risk_sort_rank("Critical"), do: 4
  defp risk_sort_rank("Elevated"), do: 3
  defp risk_sort_rank("Moderate"), do: 2
  defp risk_sort_rank("Low"), do: 1
  defp risk_sort_rank(_risk_band), do: 0

  defp action_sort_rank(:liquidation_candidate), do: 4
  defp action_sort_rank(:manual_review), do: 3
  defp action_sort_rank(:watch), do: 2
  defp action_sort_rank(:clear), do: 1

  defp operator_sort_rank(:escalated), do: 3
  defp operator_sort_rank(:unreviewed), do: 2
  defp operator_sort_rank(:reviewed), do: 1

  defp cursor_to_offset(nil), do: 0
  defp cursor_to_offset(cursor) when is_integer(cursor) and cursor >= 0, do: cursor
  defp cursor_to_offset(_cursor), do: 0

  defp next_cursor(next_offset, total_count) when next_offset < total_count, do: next_offset
  defp next_cursor(_next_offset, _total_count), do: nil

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
