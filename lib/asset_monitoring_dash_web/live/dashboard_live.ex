defmodule AssetMonitoringDashWeb.DashboardLive do
  use AssetMonitoringDashWeb, :live_view

  @event_tick_interval_ms 4_000

  alias AssetMonitoringDash.Assets
  alias AssetMonitoringDash.DemoData
  alias AssetMonitoringDash.EventFeed
  alias AssetMonitoringDash.ReviewState
  alias AssetMonitoringDash.Risk
  alias AssetMonitoringDash.RiskRecommendation
  alias AssetMonitoringDashWeb.DashboardComponents.AssetInspection
  alias AssetMonitoringDashWeb.DashboardComponents.AssetSummary
  alias AssetMonitoringDashWeb.DashboardComponents.EventItem
  alias AssetMonitoringDashWeb.DashboardComponents.RiskBadge
  alias AssetMonitoringDashWeb.Formatters
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

    socket =
      socket
      |> stream_configure(:assets, dom_id: &"asset-row-#{&1.id}")
      |> stream_configure(:events, dom_id: &"event-row-#{&1.id}")
      |> assign(:page_title, "Asset Risk Cockpit")
      |> assign(:snapshot, snapshot)
      |> assign(:metric_cards, metric_cards(snapshot))
      |> assign(:all_assets, assets)
      |> assign(:review_states, %{})
      |> assign(:shocked_asset_ids, MapSet.new())
      |> assign(:asset_count, length(assets))
      |> assign(:asset_summary, Assets.summarize_assets(assets))
      |> assign(:event_count, length(events))
      |> assign(:feed_paused, false)
      |> assign(:next_event_index, 0)
      |> assign(:chain_filter_options, Assets.chain_filter_options())
      |> assign(:asset_filters, Assets.default_filters())
      |> assign(:filter_form, filter_form(Assets.default_filters()))
      |> assign(:risk_filter_options, Assets.risk_filter_options())
      |> assign(:visible_events, events)
      |> assign_selected_asset(List.first(assets))
      |> stream(:assets, assets)
      |> stream(:events, events)

    schedule_event_tick_for_connection(connected?(socket))

    {:ok, socket}
  end

  @impl true
  def handle_event("filter_assets", %{"filters" => params}, socket) do
    filters = Assets.normalize_filters(params, socket.assigns.asset_filters)
    assets = Assets.filter_assets(socket.assigns.all_assets, filters)
    selected_asset = selected_asset_for_filter(socket.assigns.selected_asset, assets)

    socket =
      socket
      |> assign(:asset_count, length(assets))
      |> assign(:asset_summary, Assets.summarize_assets(assets))
      |> assign(:asset_filters, filters)
      |> assign(:filter_form, filter_form(filters))
      |> assign_selected_asset(selected_asset)
      |> stream(:assets, assets, reset: true)

    {:noreply, socket}
  end

  @impl true
  def handle_event("reset_asset_filters", _params, socket) do
    filters = Assets.default_filters()
    assets = Assets.filter_assets(socket.assigns.all_assets, filters)

    socket =
      socket
      |> assign(:asset_count, length(assets))
      |> assign(:asset_summary, Assets.summarize_assets(assets))
      |> assign(:asset_filters, filters)
      |> assign(:filter_form, filter_form(filters))
      |> assign_selected_asset(List.first(assets))
      |> stream(:assets, assets, reset: true)

    {:noreply, socket}
  end

  @impl true
  def handle_event("select_asset", %{"id" => asset_id}, socket) do
    selected_asset = Assets.get_asset(socket.assigns.all_assets, asset_id)

    {:noreply, select_asset(socket, selected_asset)}
  end

  @impl true
  def handle_event("apply_price_shock", _params, socket) do
    {:noreply, apply_price_shock(socket)}
  end

  @impl true
  def handle_event("reset_asset_scenario", _params, socket) do
    {:noreply, reset_asset_scenario(socket)}
  end

  @impl true
  def handle_event("mark_asset_reviewed", _params, socket) do
    {:noreply, mark_asset_reviewed(socket)}
  end

  @impl true
  def handle_event("escalate_asset_review", _params, socket) do
    {:noreply, escalate_asset_review(socket)}
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
        "risk" => filters.risk,
        "chain" => filters.chain
      },
      as: :filters
    )
  end

  defp selected_asset_for_filter(nil, assets), do: List.first(assets)

  defp selected_asset_for_filter(selected_asset, assets) do
    Enum.find(assets, &(&1.id == selected_asset.id)) || List.first(assets)
  end

  defp select_asset(socket, nil), do: socket

  defp select_asset(socket, selected_asset) do
    socket
    |> assign_selected_asset(selected_asset)
    |> refresh_visible_assets()
  end

  defp apply_price_shock(%{assigns: %{selected_asset: nil}} = socket), do: socket

  defp apply_price_shock(socket) do
    already_shocked? =
      MapSet.member?(
        socket.assigns.shocked_asset_ids,
        socket.assigns.selected_asset.id
      )

    apply_price_shock(socket, already_shocked?)
  end

  defp apply_price_shock(socket, true), do: socket

  defp apply_price_shock(socket, false) do
    asset_id = socket.assigns.selected_asset.id

    all_assets =
      Assets.apply_price_drop(
        socket.assigns.all_assets,
        asset_id,
        12
      )

    selected_asset = Assets.get_asset(all_assets, asset_id)
    feed = EventFeed.push_price_shock_event(socket.assigns.visible_events, selected_asset, 12)
    review_states = ReviewState.reset(socket.assigns.review_states, asset_id)

    socket
    |> assign(:all_assets, all_assets)
    |> assign(:review_states, review_states)
    |> assign(:shocked_asset_ids, MapSet.put(socket.assigns.shocked_asset_ids, asset_id))
    |> assign(:event_count, length(feed.visible_events))
    |> assign(:visible_events, feed.visible_events)
    |> assign_selected_asset(selected_asset)
    |> stream(:events, feed.visible_events, reset: true)
    |> refresh_visible_assets()
  end

  defp reset_asset_scenario(%{assigns: %{selected_asset: nil}} = socket), do: socket

  defp reset_asset_scenario(socket) do
    shocked? =
      MapSet.member?(
        socket.assigns.shocked_asset_ids,
        socket.assigns.selected_asset.id
      )

    reset_asset_scenario(socket, shocked?)
  end

  defp reset_asset_scenario(socket, false), do: socket

  defp reset_asset_scenario(socket, true) do
    asset_id = socket.assigns.selected_asset.id
    all_assets = Assets.reset_asset(socket.assigns.all_assets, asset_id)
    selected_asset = Assets.get_asset(all_assets, asset_id)
    feed = EventFeed.push_scenario_reset_event(socket.assigns.visible_events, selected_asset)
    review_states = ReviewState.reset(socket.assigns.review_states, asset_id)

    socket
    |> assign(:all_assets, all_assets)
    |> assign(:review_states, review_states)
    |> assign(:shocked_asset_ids, MapSet.delete(socket.assigns.shocked_asset_ids, asset_id))
    |> assign(:event_count, length(feed.visible_events))
    |> assign(:visible_events, feed.visible_events)
    |> assign_selected_asset(selected_asset)
    |> stream(:events, feed.visible_events, reset: true)
    |> refresh_visible_assets()
  end

  defp mark_asset_reviewed(%{assigns: %{selected_asset: nil}} = socket), do: socket

  defp mark_asset_reviewed(socket) do
    asset = socket.assigns.selected_asset

    review_states =
      ReviewState.mark_reviewed(socket.assigns.review_states, asset.id)

    review_state = ReviewState.state_for(asset.id, review_states)
    feed = EventFeed.push_review_event(socket.assigns.visible_events, asset, review_state)

    socket
    |> assign(:review_states, review_states)
    |> assign(:event_count, length(feed.visible_events))
    |> assign(:visible_events, feed.visible_events)
    |> assign_selected_asset(asset)
    |> stream(:events, feed.visible_events, reset: true)
  end

  defp escalate_asset_review(%{assigns: %{selected_asset: nil}} = socket), do: socket

  defp escalate_asset_review(socket) do
    asset = socket.assigns.selected_asset

    review_states =
      ReviewState.escalate(socket.assigns.review_states, asset.id)

    review_state = ReviewState.state_for(asset.id, review_states)
    feed = EventFeed.push_review_event(socket.assigns.visible_events, asset, review_state)

    socket
    |> assign(:review_states, review_states)
    |> assign(:event_count, length(feed.visible_events))
    |> assign(:visible_events, feed.visible_events)
    |> assign_selected_asset(asset)
    |> stream(:events, feed.visible_events, reset: true)
  end

  defp refresh_visible_assets(socket) do
    assets = Assets.filter_assets(socket.assigns.all_assets, socket.assigns.asset_filters)

    socket
    |> assign(:asset_count, length(assets))
    |> assign(:asset_summary, Assets.summarize_assets(assets))
    |> stream(:assets, assets, reset: true)
  end

  defp assign_selected_asset(socket, nil) do
    socket
    |> assign(:selected_asset, nil)
    |> assign(:selected_asset_id, nil)
    |> assign(:selected_asset_shocked?, false)
    |> assign(:selected_asset_health_factor, nil)
    |> assign(:selected_asset_ltv_trend, [])
    |> assign(:selected_asset_risk_explanation, nil)
    |> assign(:selected_asset_risk_recommendation, nil)
    |> assign(:selected_asset_review_state, nil)
    |> assign(:selected_asset_reviewed?, false)
    |> assign(:selected_asset_escalated?, false)
  end

  defp assign_selected_asset(socket, asset) do
    shocked_asset_ids = Map.get(socket.assigns, :shocked_asset_ids, MapSet.new())
    review_states = Map.get(socket.assigns, :review_states, %{})
    risk_recommendation = RiskRecommendation.recommendation_for(asset)
    review_state = ReviewState.state_for(asset.id, review_states)

    socket
    |> assign(:selected_asset, asset)
    |> assign(:selected_asset_id, asset.id)
    |> assign(:selected_asset_shocked?, MapSet.member?(shocked_asset_ids, asset.id))
    |> assign(:selected_asset_risk_recommendation, risk_recommendation)
    |> assign(:selected_asset_review_state, review_state)
    |> assign(:selected_asset_reviewed?, review_state.id == :reviewed)
    |> assign(:selected_asset_escalated?, review_state.id == :escalated)
    |> assign(
      :selected_asset_health_factor,
      asset |> Risk.health_factor() |> Formatters.decimal()
    )
    |> assign(:selected_asset_ltv_trend, Assets.ltv_trend(asset))
    |> assign(:selected_asset_risk_explanation, Risk.explanation(asset))
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
