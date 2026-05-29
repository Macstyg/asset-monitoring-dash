defmodule AssetMonitoringDashWeb.DashboardLive do
  use AssetMonitoringDashWeb, :live_view

  @event_tick_interval_ms 4_000

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
      |> assign(:filter_form, filter_form(Assets.default_filters()))
      |> assign(:risk_filter_options, Assets.risk_filter_options())
      |> assign(:action_filter_options, Assets.action_filter_options())
      |> assign(:operator_state_filter_options, Assets.operator_state_filter_options())
      |> assign(:visible_events, events)
      |> stream(
        :assets,
        assets_for_table(
          visible_assets(assets, Assets.default_filters(), review_states),
          review_states
        )
      )
      |> stream(:events, events)

    schedule_event_tick_for_connection(connected?(socket))

    {:ok, socket}
  end

  @impl true
  def handle_event("filter_assets", %{"filters" => params}, socket) do
    filters = Assets.normalize_filters(params, socket.assigns.asset_filters)
    assets = visible_assets(socket.assigns.all_assets, filters, socket.assigns.review_states)

    socket =
      socket
      |> assign(:asset_count, length(assets))
      |> assign(:asset_summary, Assets.summarize_assets(assets))
      |> assign(:asset_filters, filters)
      |> assign(:filter_form, filter_form(filters))
      |> stream(:assets, assets_for_table(assets, socket.assigns.review_states), reset: true)

    {:noreply, socket}
  end

  @impl true
  def handle_event("reset_asset_filters", _params, socket) do
    filters = Assets.default_filters()
    assets = visible_assets(socket.assigns.all_assets, filters, socket.assigns.review_states)

    socket =
      socket
      |> assign(:asset_count, length(assets))
      |> assign(:asset_summary, Assets.summarize_assets(assets))
      |> assign(:asset_filters, filters)
      |> assign(:filter_form, filter_form(filters))
      |> stream(:assets, assets_for_table(assets, socket.assigns.review_states), reset: true)

    {:noreply, socket}
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

  defp assets_for_table(assets, review_states) do
    Enum.map(assets, &asset_for_table(&1, review_states))
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
