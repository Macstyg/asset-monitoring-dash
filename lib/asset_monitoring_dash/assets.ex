defmodule AssetMonitoringDash.Assets do
  @moduledoc """
  Query and filter access for monitored game collateral assets.

  This module is intentionally backed by deterministic demo data for now. It
  gives the product rules a stable home before the data source becomes a repo,
  stream processor, or external integration.
  """

  import Ecto.Query

  alias AssetMonitoringDash.Assets.MarketSnapshot
  alias AssetMonitoringDash.Assets.MonitoredAsset
  alias AssetMonitoringDash.AssetScenario
  alias AssetMonitoringDash.DemoData
  alias AssetMonitoringDash.Money
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
  @deep_market_depth_min_usd Money.usd(25_000)
  @thin_market_depth_min_usd Money.usd(5_000)
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

  def resolve_persisted_asset_id("asset-" <> _rest = dom_id) do
    case persisted_asset_id(dom_id) do
      nil -> dom_id
      asset_id -> asset_id
    end
  end

  def resolve_persisted_asset_id(asset_id), do: asset_id

  def persisted_asset_id(dom_id) do
    case demo_name_from_dom_id(dom_id) do
      nil ->
        nil

      name ->
        MonitoredAsset
        |> where([asset], asset.name == ^name)
        |> select([asset], asset.id)
        |> Repo.one()
    end
  end

  def same_asset_id?(asset_id, asset_id), do: true

  def same_asset_id?("asset-" <> _rest, "asset-" <> _other_rest), do: false

  def same_asset_id?("asset-" <> _rest = dom_id, asset_id),
    do: persisted_asset_id(dom_id) == asset_id

  def same_asset_id?(asset_id, "asset-" <> _rest = dom_id),
    do: persisted_asset_id(dom_id) == asset_id

  def same_asset_id?(_asset_id, _other_asset_id), do: false

  def asset_id_in_set?(asset_id, asset_ids) do
    Enum.any?(asset_ids, &same_asset_id?(&1, asset_id))
  end

  def list_assets do
    canonical_assets = canonical_assets()

    canonical_assets ++ generated_variant_assets(canonical_assets)
  end

  def persisted_asset_count do
    Repo.aggregate(MonitoredAsset, :count)
  end

  def catalog_seeded? do
    persisted_asset_count() >= length(list_assets())
  end

  def list_persisted_assets do
    persisted_asset_base_query()
    |> order_by([asset], asc: asset.name)
    |> Repo.all()
    |> Enum.map(&persisted_asset_to_map/1)
  end

  def get_persisted_asset(asset_id) do
    asset_id
    |> persisted_asset_lookup_query()
    |> Repo.one()
    |> case do
      nil -> nil
      asset -> persisted_asset_to_map(asset)
    end
  end

  def get_persisted_asset_with_scenarios(asset_id, shocked_asset_ids) do
    case get_persisted_asset(asset_id) do
      nil ->
        nil

      asset ->
        [asset]
        |> apply_scenarios(shocked_asset_ids)
        |> List.first()
    end
  end

  def list_persisted_assets_by_ids(asset_ids, shocked_asset_ids \\ MapSet.new()) do
    resolved_asset_ids =
      asset_ids
      |> Enum.map(&resolve_persisted_asset_id/1)
      |> Enum.reject(&is_nil/1)

    case resolved_asset_ids do
      [] ->
        []

      asset_ids ->
        persisted_asset_base_query()
        |> where([asset], asset.id in ^asset_ids)
        |> Repo.all()
        |> Enum.map(&persisted_asset_to_map/1)
        |> apply_scenarios(shocked_asset_ids)
    end
  end

  def list_related_asset_candidates(asset, shocked_asset_ids, opts \\ []) do
    candidate_limit = Keyword.get(opts, :limit, 24)

    asset
    |> related_asset_candidates_query(shocked_asset_ids)
    |> limit(^candidate_limit)
    |> Repo.all()
    |> Enum.map(&persisted_asset_to_map/1)
    |> apply_scenarios(shocked_asset_ids)
  end

  def list_persisted_assets_page(opts) do
    filters = Map.fetch!(opts, :filters)
    sort = Map.fetch!(opts, :sort)
    cursor = Map.get(opts, :cursor)
    limit = Map.get(opts, :limit, 50)
    review_states = Map.get(opts, :review_states, %{})
    shocked_asset_ids = Map.get(opts, :shocked_asset_ids, MapSet.new())

    page =
      case runtime_asset_page?(filters, sort) do
        true ->
          runtime_asset_page(filters, sort, cursor, limit, review_states, shocked_asset_ids)

        false ->
          persisted_asset_page(filters, sort, cursor, limit, shocked_asset_ids)
      end

    Map.put(page, :summary, normalize_summary(page.summary))
  end

  def portfolio_snapshot(shocked_asset_ids \\ MapSet.new()) do
    baseline = portfolio_aggregate(MapSet.new())
    current = portfolio_aggregate(shocked_asset_ids)
    snapshot = DemoData.portfolio_snapshot()
    risk_score = rounded_average_score(current.average_risk_score)
    baseline_risk_score = rounded_average_score(baseline.average_risk_score)

    %{
      snapshot
      | total_collateral_value_usd: Money.usd(current.total_collateral_value_usd),
        collateral_delta_percent:
          percent_delta(current.total_collateral_value_usd, baseline.total_collateral_value_usd),
        risk_score: risk_score,
        risk_delta: risk_score - baseline_risk_score,
        risk_band: Risk.risk_band(risk_score)
    }
  end

  def risk_pressure_buckets(shocked_asset_ids \\ MapSet.new()) do
    assets =
      list_persisted_assets()
      |> apply_scenarios(shocked_asset_ids)

    assets_by_risk = Enum.group_by(assets, & &1.risk_band)

    Enum.map(@risk_filter_options, fn option ->
      assets = Map.get(assets_by_risk, option.value, [])

      %{
        id: "risk-pressure-#{slugify(option.value)}",
        label: option.label,
        value: option.value,
        tone: option.tone,
        count: length(assets),
        collateral_value_usd: assets |> Enum.map(& &1.current_value_usd) |> Money.sum(),
        average_ltv_percent: average_ltv_percent(assets)
      }
    end)
  end

  defp runtime_asset_page?(filters, %{field: field}) do
    field in [:action, :operator] or
      filter_values(filters, :actions, :action, "All") != [] or
      filter_values(filters, :operator_states, :operator_state, "All") != []
  end

  defp runtime_asset_page(filters, sort, cursor, limit, review_states, shocked_asset_ids) do
    assets =
      filters
      |> persisted_asset_query(shocked_asset_ids, sort)
      |> Repo.all()
      |> Enum.map(&persisted_asset_to_map/1)
      |> apply_scenarios(shocked_asset_ids)
      |> filter_assets_by_actions(filter_values(filters, :actions, :action, "All"))
      |> filter_assets_by_operator_states(
        filter_values(filters, :operator_states, :operator_state, "All"),
        review_states
      )
      |> sort_runtime_assets(sort, review_states)

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

  defp persisted_asset_page(filters, sort, cursor, limit, shocked_asset_ids) do
    offset = cursor_to_offset(cursor)
    query = persisted_asset_query(filters, shocked_asset_ids, sort)

    entries =
      query
      |> offset(^offset)
      |> limit(^limit)
      |> Repo.all()
      |> Enum.map(&persisted_asset_to_map/1)
      |> apply_scenarios(shocked_asset_ids)

    total_count = query |> countable_query() |> Repo.aggregate(:count)
    next_offset = offset + length(entries)

    %{
      entries: entries,
      next_cursor: next_cursor(next_offset, total_count),
      total_count: total_count,
      summary: persisted_assets_summary(filters, shocked_asset_ids)
    }
  end

  def get_asset(asset_id) do
    Enum.find(list_assets(), &asset_matches_id?(&1, asset_id))
  end

  def get_asset(assets, asset_id) do
    Enum.find(assets, &asset_matches_id?(&1, asset_id))
  end

  def price_drop_projection(asset_id, drop_percent) do
    case get_persisted_asset(asset_id) do
      nil -> nil
      asset -> reprice_asset(asset, drop_percent)
    end
  end

  def list_market_snapshots(asset_id) do
    asset_id = resolve_persisted_asset_id(asset_id)

    MarketSnapshot
    |> where([snapshot], snapshot.asset_id == ^asset_id)
    |> order_by([snapshot], asc: snapshot.observed_at)
    |> Repo.all()
    |> Enum.map(&market_snapshot_to_map/1)
  end

  def ltv_trend(%{id: "asset-" <> _rest} = asset), do: demo_ltv_trend(asset)

  def ltv_trend(asset) do
    case list_market_snapshots(asset.id) do
      [] -> demo_ltv_trend(asset)
      snapshots -> snapshots_to_ltv_trend(snapshots, asset)
    end
  end

  defp demo_ltv_trend(asset) do
    baseline_asset = get_asset(Map.get(asset, :dom_id, asset.id)) || asset
    baseline_ltv = baseline_asset.ltv_percent

    baseline_asset.id
    |> ltv_trend_offsets()
    |> Enum.zip(["6d", "5d", "4d", "3d", "2d", "1d"])
    |> Enum.map(fn {offset, label} ->
      trend_point(label, Decimal.add(Money.decimal(baseline_ltv), Money.decimal(offset)))
    end)
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
    list_assets()
    |> Enum.map(& &1.chain)
    |> Enum.uniq()
    |> Enum.sort()
    |> Enum.map(&%{label: &1, value: &1, icon: :chain})
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

  def liquidity_status(market_depth_usd) do
    cond do
      decimal_gte?(market_depth_usd, @deep_market_depth_min_usd) -> "Deep"
      decimal_gte?(market_depth_usd, @thin_market_depth_min_usd) -> "Thin"
      true -> "Illiquid"
    end
  end

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
    Enum.map(DemoData.monitored_assets(), fn asset ->
      asset
      |> Map.put(:dom_id, asset.id)
      |> normalize_risk_fields()
    end)
  end

  defp persisted_asset_to_map(asset) do
    %{
      id: asset.id,
      dom_id: demo_dom_id_from_name(asset.name),
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

  defp market_snapshot_to_map(snapshot) do
    %{
      id: snapshot.id,
      asset_id: snapshot.asset_id,
      current_value_usd: snapshot.current_value_usd,
      floor_price_usd: snapshot.floor_price_usd,
      loan_value_usd: snapshot.loan_value_usd,
      ltv_percent: snapshot.ltv_percent,
      market_depth_usd: snapshot.market_depth_usd,
      observed_at: snapshot.observed_at,
      oracle_freshness_seconds: snapshot.oracle_freshness_seconds,
      source: snapshot.source
    }
  end

  defp snapshots_to_ltv_trend(snapshots, asset) do
    snapshots
    |> Enum.with_index()
    |> Enum.map(fn {snapshot, index} ->
      trend_point(snapshot_label(index, length(snapshots)), snapshot.ltv_percent)
    end)
    |> replace_latest_trend_point(asset)
  end

  defp snapshot_label(index, total_count) when index == total_count - 1, do: "Now"
  defp snapshot_label(index, total_count), do: "#{total_count - index - 1}d"

  defp replace_latest_trend_point([], asset), do: [trend_point("Now", asset.ltv_percent)]

  defp replace_latest_trend_point(points, asset) do
    points
    |> Enum.drop(-1)
    |> Kernel.++([trend_point("Now", asset.ltv_percent)])
  end

  defp persisted_asset_base_query do
    MonitoredAsset
    |> join(:inner, [asset], chain in assoc(asset, :chain), as: :chain)
    |> join(:inner, [asset], game_ecosystem in assoc(asset, :game_ecosystem), as: :game_ecosystem)
    |> preload([chain: chain, game_ecosystem: game_ecosystem],
      chain: chain,
      game_ecosystem: game_ecosystem
    )
  end

  defp persisted_asset_lookup_query(asset_id) do
    persisted_asset_base_query()
    |> filter_persisted_asset_by_identity(asset_id)
  end

  defp filter_persisted_asset_by_identity(query, asset_id) do
    case Ecto.UUID.cast(asset_id) do
      {:ok, uuid} ->
        where(query, [asset], asset.id == ^uuid)

      :error ->
        filter_persisted_asset_by_demo_name(query, demo_name_from_dom_id(asset_id))
    end
  end

  defp filter_persisted_asset_by_demo_name(query, nil), do: where(query, [asset], false)

  defp filter_persisted_asset_by_demo_name(query, name) do
    where(query, [asset], asset.name == ^name)
  end

  defp persisted_asset_query(filters, shocked_asset_ids, sort) do
    persisted_asset_base_query()
    |> join_active_scenarios(shocked_asset_ids)
    |> filter_persisted_assets_by_query(filter_value(filters, :query, ""))
    |> filter_persisted_assets_by_risks(filter_values(filters, :risks, :risk, "All"))
    |> filter_persisted_assets_by_chains(filter_values(filters, :chains, :chain, "All chains"))
    |> order_persisted_assets(sort)
  end

  defp related_asset_candidates_query(asset, shocked_asset_ids) do
    persisted_asset_base_query()
    |> join_active_scenarios(shocked_asset_ids)
    |> where([candidate], candidate.id != ^asset.id)
    |> where([candidate], not fragment("? ~ ?", candidate.name, " V[0-9]{3}$"))
    |> where(
      [candidate, chain: chain, game_ecosystem: game_ecosystem, scenario: scenario],
      chain.name == ^asset.chain or
        game_ecosystem.name == ^asset.ecosystem or
        fragment("COALESCE(?, ?)", scenario.risk_band, candidate.risk_band) == ^asset.risk_band
    )
    |> order_by([candidate, scenario: scenario],
      desc:
        fragment(
          """
          CASE COALESCE(?, ?)
            WHEN 'Critical' THEN 4
            WHEN 'Elevated' THEN 3
            WHEN 'Moderate' THEN 2
            WHEN 'Low' THEN 1
            ELSE 0
          END
          """,
          scenario.risk_band,
          candidate.risk_band
        ),
      desc: candidate.risk_score,
      asc: candidate.name,
      asc: candidate.id
    )
  end

  defp join_active_scenarios(query, shocked_asset_ids) do
    scenario_asset_ids = scenario_asset_ids(shocked_asset_ids)

    join(query, :left, [asset], scenario in AssetScenario,
      as: :scenario,
      on:
        scenario.asset_id == asset.id and
          scenario.asset_id in ^scenario_asset_ids
    )
  end

  defp countable_query(query) do
    query
    |> exclude(:order_by)
    |> exclude(:preload)
  end

  defp persisted_assets_summary(filters, shocked_asset_ids) do
    filters
    |> persisted_asset_query(shocked_asset_ids, %{field: :asset, direction: :asc})
    |> countable_query()
    |> select([asset, scenario: scenario], %{
      visible_count: count(asset.id),
      total_value_usd:
        type(
          fragment(
            "COALESCE(SUM(COALESCE(?, ?)), 0)",
            scenario.current_value_usd,
            asset.current_value_usd
          ),
          :decimal
        ),
      at_risk_count:
        type(
          fragment(
            "COUNT(*) FILTER (WHERE COALESCE(?, ?) IN ('Elevated', 'Critical'))",
            scenario.risk_band,
            asset.risk_band
          ),
          :integer
        ),
      average_ltv_percent:
        type(
          fragment("COALESCE(AVG(COALESCE(?, ?)), 0)", scenario.ltv_percent, asset.ltv_percent),
          :decimal
        ),
      highest_ltv_percent:
        type(
          fragment("COALESCE(MAX(COALESCE(?, ?)), 0)", scenario.ltv_percent, asset.ltv_percent),
          :decimal
        )
    })
    |> Repo.one()
  end

  defp normalize_summary(nil) do
    %{
      visible_count: 0,
      total_value_usd: Decimal.new("0.00"),
      at_risk_count: 0,
      average_ltv_percent: Decimal.new("0.0"),
      highest_ltv_percent: Decimal.new("0.0")
    }
  end

  defp normalize_summary(summary) do
    %{
      visible_count: Map.get(summary, :visible_count, 0) || 0,
      total_value_usd: summary |> Map.get(:total_value_usd, 0) |> Money.usd(),
      at_risk_count: Map.get(summary, :at_risk_count, 0) || 0,
      average_ltv_percent:
        summary |> Map.get(:average_ltv_percent, 0) |> Money.decimal() |> Decimal.round(1),
      highest_ltv_percent:
        summary |> Map.get(:highest_ltv_percent, 0) |> Money.decimal() |> Decimal.round(1)
    }
  end

  defp portfolio_aggregate(shocked_asset_ids) do
    @default_filters
    |> persisted_asset_query(shocked_asset_ids, %{field: :asset, direction: :asc})
    |> countable_query()
    |> select([asset, scenario: scenario], %{
      total_collateral_value_usd:
        type(
          fragment(
            "COALESCE(SUM(COALESCE(?, ?)), 0)",
            scenario.current_value_usd,
            asset.current_value_usd
          ),
          :decimal
        ),
      average_risk_score:
        type(
          fragment("COALESCE(AVG(COALESCE(?, ?)), 0)", scenario.risk_score, asset.risk_score),
          :decimal
        )
    })
    |> Repo.one()
  end

  defp rounded_average_score(value) do
    value
    |> Money.decimal()
    |> Decimal.round(0)
    |> Decimal.to_integer()
  end

  defp percent_delta(current_value, baseline_value) do
    case Decimal.compare(Money.decimal(baseline_value), Decimal.new("0")) do
      :eq ->
        Decimal.new("0.0")

      _comparison ->
        current_value
        |> Money.decimal()
        |> Decimal.sub(Money.decimal(baseline_value))
        |> Decimal.div(Money.decimal(baseline_value))
        |> Decimal.mult(100)
        |> Decimal.round(1)
    end
  end

  defp scenario_asset_ids(shocked_asset_ids) do
    shocked_asset_ids
    |> Enum.map(&resolve_persisted_asset_id/1)
    |> Enum.reject(&is_nil/1)
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
    where(
      query,
      [asset, scenario: scenario],
      fragment("COALESCE(?, ?)", scenario.risk_band, asset.risk_band) in ^risk_filters
    )
  end

  defp filter_persisted_assets_by_chains(query, []), do: query

  defp filter_persisted_assets_by_chains(query, chain_filters) do
    where(query, [chain: chain], chain.name in ^chain_filters)
  end

  defp order_persisted_assets(query, %{field: :asset, direction: :desc}) do
    order_by(query, [asset], desc: asset.name, asc: asset.id)
  end

  defp order_persisted_assets(query, %{field: :asset}) do
    order_by(query, [asset], asc: asset.name, asc: asset.id)
  end

  defp order_persisted_assets(query, %{field: :chain, direction: :desc}) do
    order_by(query, [asset, chain: chain, game_ecosystem: game_ecosystem],
      desc: chain.name,
      desc: game_ecosystem.name,
      asc: asset.name,
      asc: asset.id
    )
  end

  defp order_persisted_assets(query, %{field: :chain}) do
    order_by(query, [asset, chain: chain, game_ecosystem: game_ecosystem],
      asc: chain.name,
      asc: game_ecosystem.name,
      asc: asset.name,
      asc: asset.id
    )
  end

  defp order_persisted_assets(query, %{field: :floor, direction: :desc}) do
    order_by(query, [asset], desc: asset.floor_price_usd, asc: asset.name, asc: asset.id)
  end

  defp order_persisted_assets(query, %{field: :floor}) do
    order_by(query, [asset], asc: asset.floor_price_usd, asc: asset.name, asc: asset.id)
  end

  defp order_persisted_assets(query, %{field: :value, direction: :desc}) do
    order_by(query, [asset, scenario: scenario],
      desc: fragment("COALESCE(?, ?)", scenario.current_value_usd, asset.current_value_usd),
      asc: asset.name,
      asc: asset.id
    )
  end

  defp order_persisted_assets(query, %{field: :value}) do
    order_by(query, [asset, scenario: scenario],
      asc: fragment("COALESCE(?, ?)", scenario.current_value_usd, asset.current_value_usd),
      asc: asset.name,
      asc: asset.id
    )
  end

  defp order_persisted_assets(query, %{field: :ltv, direction: :desc}) do
    order_by(query, [asset, scenario: scenario],
      desc: fragment("COALESCE(?, ?)", scenario.ltv_percent, asset.ltv_percent),
      asc: asset.name,
      asc: asset.id
    )
  end

  defp order_persisted_assets(query, %{field: :ltv}) do
    order_by(query, [asset, scenario: scenario],
      asc: fragment("COALESCE(?, ?)", scenario.ltv_percent, asset.ltv_percent),
      asc: asset.name,
      asc: asset.id
    )
  end

  defp order_persisted_assets(query, %{field: :risk, direction: :desc}) do
    order_by(query, [asset, scenario: scenario],
      desc:
        fragment(
          """
          CASE COALESCE(?, ?)
            WHEN 'Critical' THEN 4
            WHEN 'Elevated' THEN 3
            WHEN 'Moderate' THEN 2
            WHEN 'Low' THEN 1
            ELSE 0
          END
          """,
          scenario.risk_band,
          asset.risk_band
        ),
      asc: asset.name,
      asc: asset.id
    )
  end

  defp order_persisted_assets(query, %{field: :risk}) do
    order_by(query, [asset, scenario: scenario],
      asc:
        fragment(
          """
          CASE COALESCE(?, ?)
            WHEN 'Critical' THEN 4
            WHEN 'Elevated' THEN 3
            WHEN 'Moderate' THEN 2
            WHEN 'Low' THEN 1
            ELSE 0
          END
          """,
          scenario.risk_band,
          asset.risk_band
        ),
      asc: asset.name,
      asc: asset.id
    )
  end

  defp order_persisted_assets(query, _sort) do
    order_by(query, [asset], asc: asset.name, asc: asset.id)
  end

  defp apply_scenarios(assets, shocked_asset_ids) do
    scenarios_by_asset_id = active_scenarios_for(shocked_asset_ids)

    Enum.map(assets, &apply_stored_scenario(&1, scenarios_by_asset_id))
  end

  defp active_scenarios_for(shocked_asset_ids) do
    asset_ids =
      shocked_asset_ids
      |> Enum.map(&resolve_persisted_asset_id/1)
      |> Enum.reject(&is_nil/1)

    case asset_ids do
      [] ->
        %{}

      asset_ids ->
        AssetScenario
        |> where([scenario], scenario.asset_id in ^asset_ids)
        |> Repo.all()
        |> Map.new(&{&1.asset_id, &1})
    end
  end

  defp apply_stored_scenario(asset, scenarios_by_asset_id) do
    case Map.fetch(scenarios_by_asset_id, asset.id) do
      :error ->
        asset

      {:ok, scenario} ->
        asset
        |> Map.merge(%{
          current_value_usd: scenario.current_value_usd,
          loan_value_usd: scenario.loan_value_usd,
          ltv_percent: scenario.ltv_percent,
          market_depth_usd: scenario.market_depth_usd,
          oracle_freshness_seconds: scenario.oracle_freshness_seconds,
          risk_score: scenario.risk_score,
          risk_band: scenario.risk_band
        })
        |> Map.put(:oracle_status, oracle_status(scenario.oracle_freshness_seconds))
        |> Map.put(:liquidity_status, liquidity_status(scenario.market_depth_usd))
    end
  end

  defp slugify(value) do
    value
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
  end

  defp demo_dom_id_from_name(name) do
    canonical_names_by_id =
      DemoData.monitored_assets()
      |> Map.new(&{&1.name, &1.id})

    case Map.fetch(canonical_names_by_id, name) do
      {:ok, dom_id} -> dom_id
      :error -> variant_dom_id_from_name(name, canonical_names_by_id)
    end
  end

  defp variant_dom_id_from_name(name, canonical_names_by_id) do
    case Regex.run(~r/^(.+) V(\d{3})$/, name) do
      [_name, base_name, suffix] ->
        case Map.fetch(canonical_names_by_id, base_name) do
          {:ok, dom_id} -> "#{dom_id}-variant-#{suffix}"
          :error -> slugify(name)
        end

      _no_match ->
        slugify(name)
    end
  end

  defp demo_name_from_dom_id(dom_id) do
    canonical_assets_by_id =
      DemoData.monitored_assets()
      |> Map.new(&{&1.id, &1.name})

    case Map.fetch(canonical_assets_by_id, dom_id) do
      {:ok, name} -> name
      :error -> variant_name_from_dom_id(dom_id, canonical_assets_by_id)
    end
  end

  defp variant_name_from_dom_id(dom_id, canonical_assets_by_id) do
    case Regex.run(~r/^(asset-\d{3})-variant-(\d{3})$/, dom_id) do
      [_dom_id, base_dom_id, suffix] ->
        case Map.fetch(canonical_assets_by_id, base_dom_id) do
          {:ok, name} -> "#{name} V#{suffix}"
          :error -> nil
        end

      _no_match ->
        nil
    end
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
    dom_id = "#{canonical_asset_code(asset_index)}-variant-#{suffix}"
    current_factor = 0.86 + rem(sequence * 7, 29) / 100
    ltv_factor = 0.72 + rem(sequence * 5, 24) / 100
    floor_factor = current_factor * (0.92 + rem(sequence * 11, 17) / 100)
    depth_factor = 0.35 + rem(sequence * 13, 170) / 100

    %{
      asset
      | id: dom_id,
        dom_id: dom_id,
        name: "#{asset.name} V#{suffix}",
        floor_price_usd: asset.floor_price_usd |> Money.multiply(floor_factor) |> Money.max(1),
        current_value_usd:
          asset.current_value_usd |> Money.multiply(current_factor) |> Money.max(1),
        loan_value_usd:
          asset.loan_value_usd
          |> Money.multiply(current_factor * ltv_factor)
          |> Money.max(1),
        oracle_freshness_seconds: variant_oracle_freshness(sequence),
        market_depth_usd: asset.market_depth_usd |> Money.multiply(depth_factor) |> Money.max(500)
    }
  end

  defp variant_suffix(variant_index) do
    variant_index
    |> Integer.to_string()
    |> String.pad_leading(3, "0")
  end

  defp canonical_asset_code(asset_index) do
    "asset-#{String.pad_leading(Integer.to_string(asset_index + 1), 3, "0")}"
  end

  defp variant_oracle_freshness(sequence) do
    Enum.at([18, 24, 36, 58, 92, 184, 216, 420, 620, 760], rem(sequence, 10))
  end

  defp sort_assets(assets, sort, review_states) do
    Enum.sort(assets, &asset_before?(&1, &2, sort, review_states))
  end

  defp sort_runtime_assets(assets, %{field: field} = sort, review_states)
       when field in [:action, :operator] do
    sort_assets(assets, sort, review_states)
  end

  defp sort_runtime_assets(assets, _sort, _review_states), do: assets

  defp asset_before?(asset, other_asset, %{field: field, direction: direction}, review_states) do
    asset_value = sort_value(asset, field, review_states)
    other_value = sort_value(other_asset, field, review_states)

    case compare_sort_values(asset_value, other_value, direction) do
      :before -> true
      :after -> false
      :same -> asset_tiebreaker(asset) <= asset_tiebreaker(other_asset)
    end
  end

  defp compare_sort_values(value, value, _direction), do: :same

  defp compare_sort_values(%Decimal{} = value, %Decimal{} = other_value, direction) do
    value
    |> Decimal.compare(other_value)
    |> decimal_sort_result(direction)
  end

  defp compare_sort_values(value, other_value, :asc) when value < other_value, do: :before
  defp compare_sort_values(_value, _other_value, :asc), do: :after
  defp compare_sort_values(value, other_value, :desc) when value > other_value, do: :before
  defp compare_sort_values(_value, _other_value, :desc), do: :after

  defp decimal_sort_result(:eq, _direction), do: :same
  defp decimal_sort_result(:lt, :asc), do: :before
  defp decimal_sort_result(:gt, :asc), do: :after
  defp decimal_sort_result(:gt, :desc), do: :before
  defp decimal_sort_result(:lt, :desc), do: :after

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

  defp asset_tiebreaker(asset), do: Map.get(asset, :dom_id, asset.id)

  defp cursor_to_offset(nil), do: 0
  defp cursor_to_offset(cursor) when is_integer(cursor) and cursor >= 0, do: cursor
  defp cursor_to_offset(_cursor), do: 0

  defp next_cursor(next_offset, total_count) when next_offset < total_count, do: next_offset
  defp next_cursor(_next_offset, _total_count), do: nil

  defp ltv_trend_offsets(asset_id) do
    Map.get(@ltv_trend_offsets, asset_id, [-2.0, -1.5, -1.1, -0.7, -0.4, -0.2])
  end

  defp trend_point(label, value) do
    %{label: label, value: value |> clamp_ltv() |> Decimal.round(1)}
  end

  defp clamp_ltv(value) do
    cond do
      decimal_lt?(value, 0) -> Decimal.new("0.0")
      decimal_gt?(value, 100) -> Decimal.new("100.0")
      true -> Money.decimal(value)
    end
  end

  defp normalize_risk_fields(asset) do
    asset = normalize_numeric_fields(asset)
    ltv_percent = Risk.ltv_percent(asset)
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

  defp reprice_asset(asset, drop_percent) do
    value_multiplier = 1 - drop_percent / 100
    current_value_usd = Money.multiply(asset.current_value_usd, value_multiplier)
    repriced_asset = %{asset | current_value_usd: current_value_usd}
    ltv_percent = Risk.ltv_percent(repriced_asset)
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

  defp asset_matches_id?(asset, asset_id) do
    asset.id == asset_id || Map.get(asset, :dom_id) == asset_id
  end

  defp total_value_usd(assets), do: assets |> Enum.map(& &1.current_value_usd) |> Money.sum()

  defp at_risk_count(assets) do
    Enum.count(assets, &(&1.risk_band in @at_risk_bands))
  end

  defp average_ltv_percent([]), do: Decimal.new("0.0")

  defp average_ltv_percent(assets) do
    assets
    |> Enum.map(& &1.ltv_percent)
    |> Enum.reduce(Decimal.new("0"), fn value, total ->
      Decimal.add(total, Money.decimal(value))
    end)
    |> Decimal.div(length(assets))
    |> Decimal.round(1)
  end

  defp highest_ltv_percent([]), do: Decimal.new("0.0")

  defp highest_ltv_percent(assets) do
    assets
    |> Enum.map(& &1.ltv_percent)
    |> Enum.max_by(&Money.decimal/1, Decimal)
  end

  defp normalize_numeric_fields(asset) do
    %{
      asset
      | current_value_usd: Money.usd(asset.current_value_usd),
        floor_price_usd: Money.usd(asset.floor_price_usd),
        loan_value_usd: Money.usd(asset.loan_value_usd),
        ltv_percent: Money.decimal(asset.ltv_percent),
        market_depth_usd: Money.usd(asset.market_depth_usd)
    }
  end

  defp decimal_gte?(value, threshold),
    do: Decimal.compare(Money.decimal(value), Money.decimal(threshold)) in [:gt, :eq]

  defp decimal_gt?(value, threshold),
    do: Decimal.compare(Money.decimal(value), Money.decimal(threshold)) == :gt

  defp decimal_lt?(value, threshold),
    do: Decimal.compare(Money.decimal(value), Money.decimal(threshold)) == :lt
end
