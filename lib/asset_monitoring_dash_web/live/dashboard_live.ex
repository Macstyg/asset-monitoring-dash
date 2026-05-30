defmodule AssetMonitoringDashWeb.DashboardLive do
  use AssetMonitoringDashWeb, :live_view

  @event_tick_interval_ms 4_000
  @default_asset_sort %{field: :ltv, direction: :desc}

  alias AssetMonitoringDash.Assets
  alias AssetMonitoringDash.DemoData
  alias AssetMonitoringDash.EventFeed
  alias AssetMonitoringDash.ReviewState
  alias AssetMonitoringDash.ReviewStore
  alias AssetMonitoringDash.RiskRecommendation
  alias AssetMonitoringDashWeb.DashboardComponents.AssetSummary
  alias AssetMonitoringDashWeb.DashboardComponents.ChainIdentity
  alias AssetMonitoringDashWeb.DashboardComponents.EventItem
  alias AssetMonitoringDashWeb.DashboardComponents.RiskBadge
  alias AssetMonitoringDashWeb.Formatters
  alias AssetMonitoringDashWeb.UI.Badge
  alias AssetMonitoringDashWeb.UI.Button
  alias AssetMonitoringDashWeb.UI.Card
  alias AssetMonitoringDashWeb.UI.EntityIdentity
  alias AssetMonitoringDashWeb.UI.FilterBar
  alias AssetMonitoringDashWeb.UI.Table
  alias AssetMonitoringDashWeb.UI.ThemeSwitch

  @impl true
  def mount(_params, _session, socket) do
    snapshot = DemoData.portfolio_snapshot()
    assets = Assets.list_assets()
    events = EventFeed.initial_events()
    review_states = ReviewStore.all_states()

    socket =
      socket
      |> stream_configure(:assets, dom_id: &"asset-row-#{&1.id}")
      |> stream_configure(:events, dom_id: &"event-row-#{&1.id}")
      |> assign(:page_title, "Asset Risk Cockpit")
      |> assign(:snapshot, snapshot)
      |> assign(:metric_cards, metric_cards(snapshot))
      |> assign(:all_assets, assets)
      |> assign(:review_states, review_states)
      |> assign(:asset_count, length(assets))
      |> assign(
        :asset_summary,
        Assets.summarize_assets(visible_assets(assets, Assets.default_filters(), review_states))
      )
      |> assign(:event_count, length(events))
      |> assign(:feed_paused, false)
      |> assign(:next_event_index, 0)
      |> assign(:chain_filter_options, Assets.chain_filter_options())
      |> assign(:asset_filters, Assets.default_filters())
      |> assign(:asset_sort, @default_asset_sort)
      |> assign(:active_filter_chips, active_filter_chips(Assets.default_filters()))
      |> assign(:filter_form, filter_form(Assets.default_filters()))
      |> assign(:risk_filter_options, Assets.risk_filter_options())
      |> assign(:action_filter_options, Assets.action_filter_options())
      |> assign(:operator_state_filter_options, Assets.operator_state_filter_options())
      |> assign(:visible_events, events)
      |> stream(
        :assets,
        assets_for_table(
          visible_assets(assets, Assets.default_filters(), review_states),
          review_states,
          @default_asset_sort
        )
      )
      |> stream(:events, events)

    schedule_event_tick_for_connection(connected?(socket))

    {:ok, socket}
  end

  @impl true
  def handle_event("filter_assets", %{"filters" => params}, socket) do
    filters = Assets.normalize_filters(params, socket.assigns.asset_filters)

    {:noreply, apply_asset_filters(socket, filters)}
  end

  @impl true
  def handle_event("reset_asset_filters", _params, socket) do
    {:noreply, apply_asset_filters(socket, Assets.default_filters())}
  end

  @impl true
  def handle_event("sort_assets", %{"field" => field}, socket) do
    sort =
      field
      |> normalize_sort_field()
      |> next_sort(socket.assigns.asset_sort)

    socket =
      socket
      |> assign(:asset_sort, sort)
      |> apply_asset_filters(socket.assigns.asset_filters)

    {:noreply, socket}
  end

  @impl true
  def handle_event("remove_filter_value", %{"filter" => "query"}, socket) do
    filters = %{socket.assigns.asset_filters | query: ""}

    {:noreply, apply_asset_filters(socket, filters)}
  end

  @impl true
  def handle_event("remove_filter_value", %{"filter" => "chains", "option" => value}, socket) do
    {:noreply, remove_filter_value(socket, :chains, value)}
  end

  @impl true
  def handle_event("remove_filter_value", %{"filter" => "risks", "option" => value}, socket) do
    {:noreply, remove_filter_value(socket, :risks, value)}
  end

  @impl true
  def handle_event("remove_filter_value", %{"filter" => "actions", "option" => value}, socket) do
    {:noreply, remove_filter_value(socket, :actions, value)}
  end

  @impl true
  def handle_event(
        "remove_filter_value",
        %{"filter" => "operator_states", "option" => value},
        socket
      ) do
    {:noreply, remove_filter_value(socket, :operator_states, value)}
  end

  @impl true
  def handle_event("select_asset", %{"id" => asset_id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/assets/#{asset_id}")}
  end

  @impl true
  def handle_event("push_demo_event", _params, socket) do
    {:noreply, push_demo_event(socket)}
  end

  @impl true
  def handle_event("toggle_event_feed", _params, socket) do
    feed_paused = !socket.assigns.feed_paused

    schedule_event_tick_for_feed(feed_paused)

    {:noreply, assign(socket, :feed_paused, feed_paused)}
  end

  @impl true
  def handle_info(:push_demo_event, socket) do
    {:noreply, push_scheduled_demo_event(socket)}
  end

  defp metric_cards(snapshot) do
    [
      %{
        id: "collateral-value-card",
        label: "Collateral value",
        context: "24H",
        value: Formatters.compact_usd(snapshot.total_collateral_value_usd),
        delta: Formatters.signed_percent(snapshot.collateral_delta_percent),
        delta_tone: :positive,
        description: "collateral inflow"
      },
      %{
        id: "active-loans-card",
        label: "Active loans",
        context: "OPEN",
        value: Integer.to_string(snapshot.active_loans),
        delta: "+#{snapshot.active_loans_delta} today",
        delta_tone: :neutral,
        description: "borrow positions"
      },
      %{
        id: "weighted-apy-card",
        label: "Weighted APY",
        context: "BLENDED",
        value: Formatters.ltv(snapshot.weighted_apy_percent),
        delta: Formatters.signed_percent(snapshot.apy_delta_percent),
        delta_tone: :negative,
        description: "since last rebalance"
      },
      %{
        id: "risk-score-card",
        label: "Risk score",
        context: "HEALTH < 1.2",
        value: "#{snapshot.risk_score}/100",
        delta: "+#{snapshot.risk_delta} risk",
        delta_tone: :warning,
        description: "#{String.downcase(snapshot.risk_band)} pressure"
      }
    ]
  end

  defp apply_asset_filters(socket, filters) do
    assets = visible_assets(socket.assigns.all_assets, filters, socket.assigns.review_states)

    socket
    |> assign(:asset_count, length(assets))
    |> assign(:asset_summary, Assets.summarize_assets(assets))
    |> assign(:asset_filters, filters)
    |> assign(:active_filter_chips, active_filter_chips(filters))
    |> assign(:filter_form, filter_form(filters))
    |> stream(
      :assets,
      assets_for_table(assets, socket.assigns.review_states, socket.assigns.asset_sort),
      reset: true
    )
  end

  defp remove_filter_value(socket, field, value) do
    filters =
      Map.update!(socket.assigns.asset_filters, field, fn values ->
        Enum.reject(values, &(&1 == value))
      end)

    apply_asset_filters(socket, filters)
  end

  defp active_filter_chips(filters) do
    []
    |> active_query_chip(filters.query)
    |> active_option_chips("Network", "chains", filters.chains, Assets.chain_filter_options())
    |> active_option_chips("Risk", "risks", filters.risks, Assets.risk_filter_options())
    |> active_option_chips("Action", "actions", filters.actions, Assets.action_filter_options())
    |> active_option_chips(
      "Operator",
      "operator_states",
      filters.operator_states,
      Assets.operator_state_filter_options()
    )
  end

  defp active_query_chip(chips, ""), do: chips

  defp active_query_chip(chips, query) do
    chips ++
      [
        %{
          id: "query-#{chip_id(query)}",
          field: "query",
          value: query,
          group: "Search",
          label: query,
          icon: "hero-magnifying-glass"
        }
      ]
  end

  defp active_option_chips(chips, group, field, values, options) do
    options_by_value = Map.new(options, &{&1.value, &1})
    option_chips = Enum.map(values, &active_option_chip(group, field, &1, options_by_value[&1]))

    chips ++ option_chips
  end

  defp active_option_chip(group, field, value, nil) do
    %{
      id: "#{field}-#{chip_id(value)}",
      field: field,
      value: value,
      group: group,
      label: value
    }
  end

  defp active_option_chip(group, field, value, option) do
    option
    |> Map.take([:icon, :icon_text, :label, :tone])
    |> Map.merge(%{
      id: "#{field}-#{chip_id(value)}",
      field: field,
      value: value,
      group: group
    })
  end

  defp chip_id(value) do
    value
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9_-]/, "-")
  end

  defp filter_form(filters) do
    to_form(
      %{
        "query" => filters.query,
        "risks" => filters.risks,
        "chains" => filters.chains,
        "actions" => filters.actions,
        "operator_states" => filters.operator_states,
        "risk_option_query" => filters.risk_option_query,
        "chain_option_query" => filters.chain_option_query,
        "action_option_query" => filters.action_option_query,
        "operator_state_option_query" => filters.operator_state_option_query
      },
      as: :filters
    )
  end

  defp visible_filter_options(options, query) do
    Assets.filter_options(options, query)
  end

  defp visible_assets(assets, filters, review_states) do
    Assets.filter_assets(assets, filters, review_states)
  end

  defp assets_for_table(assets, review_states, sort) do
    assets
    |> Enum.map(&asset_for_table(&1, review_states))
    |> sort_assets_for_table(sort)
  end

  defp asset_for_table(asset, review_states) do
    recommendation = RiskRecommendation.recommendation_for(asset)
    review_state = ReviewState.state_for(asset.id, review_states)

    Map.merge(asset, %{
      risk_recommendation: recommendation,
      recommendation_reason: List.first(recommendation.reasons),
      review_state: review_state
    })
  end

  defp normalize_sort_field("value"), do: :value
  defp normalize_sort_field("ltv"), do: :ltv
  defp normalize_sort_field("risk"), do: :risk
  defp normalize_sort_field("action"), do: :action
  defp normalize_sort_field(_field), do: @default_asset_sort.field

  defp next_sort(field, %{field: field, direction: :desc}), do: %{field: field, direction: :asc}
  defp next_sort(field, %{field: field, direction: :asc}), do: %{field: field, direction: :desc}
  defp next_sort(field, _current_sort), do: %{field: field, direction: :desc}

  defp sort_assets_for_table(assets, sort) do
    Enum.sort(assets, &asset_before?(&1, &2, sort))
  end

  defp asset_before?(asset, other_asset, %{field: field, direction: direction}) do
    asset_value = sort_value(asset, field)
    other_value = sort_value(other_asset, field)

    case compare_sort_values(asset_value, other_value, direction) do
      :before -> true
      :after -> false
      :same -> asset.name <= other_asset.name
    end
  end

  defp compare_sort_values(value, value, _direction), do: :same
  defp compare_sort_values(value, other_value, :asc) when value < other_value, do: :before
  defp compare_sort_values(_value, _other_value, :asc), do: :after
  defp compare_sort_values(value, other_value, :desc) when value > other_value, do: :before
  defp compare_sort_values(_value, _other_value, :desc), do: :after

  defp sort_value(asset, :value), do: asset.current_value_usd
  defp sort_value(asset, :ltv), do: asset.ltv_percent
  defp sort_value(asset, :risk), do: risk_sort_rank(asset.risk_band)
  defp sort_value(asset, :action), do: action_sort_rank(asset.risk_recommendation.id)

  defp risk_sort_rank("Critical"), do: 4
  defp risk_sort_rank("Elevated"), do: 3
  defp risk_sort_rank("Moderate"), do: 2
  defp risk_sort_rank("Low"), do: 1
  defp risk_sort_rank(_risk_band), do: 0

  defp action_sort_rank(:liquidation_candidate), do: 4
  defp action_sort_rank(:manual_review), do: 3
  defp action_sort_rank(:watch), do: 2
  defp action_sort_rank(:clear), do: 1
  defp action_sort_rank(_recommendation), do: 0

  defp push_demo_event(socket) do
    feed =
      EventFeed.push_demo_event(
        socket.assigns.visible_events,
        socket.assigns.next_event_index
      )

    socket
    |> assign(:event_count, length(feed.visible_events))
    |> assign(:next_event_index, feed.next_event_index)
    |> assign(:visible_events, feed.visible_events)
    |> stream(:events, feed.visible_events, reset: true)
  end

  defp push_scheduled_demo_event(%{assigns: %{feed_paused: true}} = socket), do: socket

  defp push_scheduled_demo_event(%{assigns: %{feed_paused: false}} = socket) do
    schedule_event_tick()
    push_demo_event(socket)
  end

  defp schedule_event_tick_for_connection(true), do: schedule_event_tick()
  defp schedule_event_tick_for_connection(false), do: :ok

  defp schedule_event_tick_for_feed(false), do: schedule_event_tick()
  defp schedule_event_tick_for_feed(true), do: :ok

  defp schedule_event_tick do
    Process.send_after(self(), :push_demo_event, @event_tick_interval_ms)
  end
end
