defmodule AssetMonitoringDashWeb.DashboardLive do
  use AssetMonitoringDashWeb, :live_view

  @event_tick_interval_ms 4_000
  @max_visible_events 6

  alias AssetMonitoringDash.DemoData
  alias AssetMonitoringDash.Risk
  alias AssetMonitoringDashWeb.DashboardComponents.AssetInspection
  alias AssetMonitoringDashWeb.DashboardComponents.EventItem
  alias AssetMonitoringDashWeb.DashboardComponents.RiskBadge
  alias AssetMonitoringDashWeb.Formatters
  alias AssetMonitoringDashWeb.UI.Button
  alias AssetMonitoringDashWeb.UI.Card
  alias AssetMonitoringDashWeb.UI.EntityIdentity
  alias AssetMonitoringDashWeb.UI.Table

  @impl true
  def mount(_params, _session, socket) do
    snapshot = DemoData.portfolio_snapshot()
    assets = DemoData.monitored_assets()
    events = DemoData.live_events()

    socket =
      socket
      |> stream_configure(:assets, dom_id: &"asset-row-#{&1.id}")
      |> stream_configure(:events, dom_id: &"event-row-#{&1.id}")
      |> assign(:page_title, "Asset Risk Cockpit")
      |> assign(:snapshot, snapshot)
      |> assign(:metric_cards, metric_cards(snapshot))
      |> assign(:asset_count, length(assets))
      |> assign(:event_count, length(events))
      |> assign(:feed_paused, false)
      |> assign(:next_event_index, 0)
      |> assign(:risk_filter, "All")
      |> assign(:risk_filter_options, risk_filter_options())
      |> assign(:visible_events, events)
      |> assign_selected_asset(List.first(assets))
      |> stream(:assets, assets)
      |> stream(:events, events)

    schedule_event_tick_for_connection(connected?(socket))

    {:ok, socket}
  end

  @impl true
  def handle_event("filter_risk", %{"risk" => risk}, socket) do
    risk_filter = normalize_risk_filter(risk)
    assets = filtered_assets(risk_filter)
    selected_asset = selected_asset_for_filter(socket.assigns.selected_asset, assets)

    socket =
      socket
      |> assign(:asset_count, length(assets))
      |> assign(:risk_filter, risk_filter)
      |> assign_selected_asset(selected_asset)
      |> stream(:assets, assets, reset: true)

    {:noreply, socket}
  end

  @impl true
  def handle_event("select_asset", %{"id" => asset_id}, socket) do
    selected_asset = Enum.find(DemoData.monitored_assets(), &(&1.id == asset_id))

    {:noreply, select_asset(socket, selected_asset)}
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

  defp filtered_assets("All"), do: DemoData.monitored_assets()

  defp filtered_assets(risk_filter) do
    Enum.filter(DemoData.monitored_assets(), &(&1.risk_band == risk_filter))
  end

  defp normalize_risk_filter(risk)
       when risk in ["All", "Low", "Moderate", "Elevated", "Critical"] do
    risk
  end

  defp normalize_risk_filter(_risk), do: "All"

  defp risk_filter_options, do: ["All", "Low", "Moderate", "Elevated", "Critical"]

  defp selected_asset_for_filter(nil, assets), do: List.first(assets)

  defp selected_asset_for_filter(selected_asset, assets) do
    Enum.find(assets, &(&1.id == selected_asset.id)) || List.first(assets)
  end

  defp select_asset(socket, nil), do: socket

  defp select_asset(socket, selected_asset) do
    socket
    |> assign_selected_asset(selected_asset)
    |> stream(:assets, filtered_assets(socket.assigns.risk_filter), reset: true)
  end

  defp assign_selected_asset(socket, nil) do
    socket
    |> assign(:selected_asset, nil)
    |> assign(:selected_asset_id, nil)
    |> assign(:selected_asset_health_factor, nil)
  end

  defp assign_selected_asset(socket, asset) do
    socket
    |> assign(:selected_asset, asset)
    |> assign(:selected_asset_id, asset.id)
    |> assign(
      :selected_asset_health_factor,
      asset |> Risk.health_factor() |> Formatters.decimal()
    )
  end

  defp push_demo_event(socket) do
    event = DemoData.next_live_event(socket.assigns.next_event_index)

    visible_events =
      [event | socket.assigns.visible_events]
      |> Enum.take(@max_visible_events)
      |> refresh_live_event_labels()

    socket
    |> assign(:event_count, length(visible_events))
    |> assign(:next_event_index, socket.assigns.next_event_index + 1)
    |> assign(:visible_events, visible_events)
    |> stream(:events, visible_events, reset: true)
  end

  defp refresh_live_event_labels(events) do
    events
    |> Enum.with_index()
    |> Enum.map(fn {event, index} -> refresh_live_event_label(event, index) end)
  end

  defp refresh_live_event_label(%{id: "event-live-" <> _id} = event, 0) do
    %{event | time_label: "now"}
  end

  defp refresh_live_event_label(%{id: "event-live-" <> _id} = event, index) do
    %{event | time_label: "#{index * 4}s ago"}
  end

  defp refresh_live_event_label(event, _index), do: event

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
