defmodule AssetMonitoringDashWeb.AssetLive do
  use AssetMonitoringDashWeb, :live_view

  alias AssetMonitoringDash.Assets
  alias AssetMonitoringDash.AssetScenarioStore
  alias AssetMonitoringDash.EventFeed
  alias AssetMonitoringDash.EventStore
  alias AssetMonitoringDash.ReviewState
  alias AssetMonitoringDash.ReviewStore
  alias AssetMonitoringDash.Risk
  alias AssetMonitoringDash.RiskRecommendation
  alias AssetMonitoringDashWeb.DashboardComponents.AssetInspection
  alias AssetMonitoringDashWeb.DashboardComponents.EventItem
  alias AssetMonitoringDashWeb.Formatters
  alias AssetMonitoringDashWeb.UI.Badge
  alias AssetMonitoringDashWeb.UI.Button

  @impl true
  def mount(%{"id" => asset_id} = params, _session, socket) do
    shocked_asset_ids = AssetScenarioStore.shocked_asset_ids()
    assets = Assets.list_assets_with_scenarios(shocked_asset_ids)

    socket =
      socket
      |> stream_configure(:events, dom_id: &"asset-event-row-#{&1.id}")
      |> assign(:page_title, "Asset detail")
      |> assign(:all_assets, assets)
      |> assign(:review_states, ReviewStore.all_states())
      |> assign(:shocked_asset_ids, shocked_asset_ids)
      |> assign(:return_to, normalize_return_to(Map.get(params, "return_to")))
      |> assign(:visible_events, [])
      |> assign(:event_count, 0)
      |> stream(:events, [])
      |> assign_asset_from_id(asset_id)

    {:ok, socket}
  end

  @impl true
  def handle_event("apply_price_shock", _params, socket) do
    {:noreply, apply_price_shock(socket, socket.assigns.asset_shocked?)}
  end

  @impl true
  def handle_event("reset_asset_scenario", _params, socket) do
    {:noreply, reset_asset_scenario(socket, socket.assigns.asset_shocked?)}
  end

  @impl true
  def handle_event("mark_asset_reviewed", _params, socket) do
    {:noreply, mark_asset_reviewed(socket)}
  end

  @impl true
  def handle_event("escalate_asset_review", _params, socket) do
    {:noreply, escalate_asset_review(socket)}
  end

  defp assign_asset_from_id(socket, asset_id) do
    asset = Assets.get_asset(socket.assigns.all_assets, asset_id)

    assign_asset(socket, asset)
  end

  defp assign_asset(socket, nil) do
    socket
    |> put_flash(:error, "Asset not found")
    |> push_navigate(to: ~p"/")
  end

  defp assign_asset(socket, asset) do
    review_state = ReviewState.state_for(asset.id, socket.assigns.review_states)
    risk_recommendation = RiskRecommendation.recommendation_for(asset)

    socket
    |> assign(:page_title, "#{asset.name} · Asset detail")
    |> assign(:asset, asset)
    |> assign(:asset_shocked?, MapSet.member?(socket.assigns.shocked_asset_ids, asset.id))
    |> assign(:asset_reviewed?, review_state.id == :reviewed)
    |> assign(:asset_escalated?, review_state.id == :escalated)
    |> assign(:asset_health_factor, asset |> Risk.health_factor() |> Formatters.decimal())
    |> assign(:asset_ltv_trend, Assets.ltv_trend(asset))
    |> assign(:asset_risk_explanation, Risk.explanation(asset))
    |> assign(:asset_risk_recommendation, risk_recommendation)
    |> assign(:asset_review_state, review_state)
  end

  defp apply_price_shock(socket, true), do: socket

  defp apply_price_shock(socket, false) do
    asset_id = socket.assigns.asset.id
    shocked_asset_ids = AssetScenarioStore.apply_price_shock(asset_id)
    all_assets = Assets.list_assets_with_scenarios(shocked_asset_ids)
    asset = Assets.get_asset(all_assets, asset_id)
    feed = EventFeed.push_price_shock_event(socket.assigns.visible_events, asset, 12)
    EventStore.push_price_shock_event(asset, 12)
    review_states = ReviewStore.reset(asset_id)

    socket
    |> assign(:all_assets, all_assets)
    |> assign(:review_states, review_states)
    |> assign(:shocked_asset_ids, shocked_asset_ids)
    |> assign_events(feed.visible_events)
    |> assign_asset(asset)
  end

  defp reset_asset_scenario(socket, false), do: socket

  defp reset_asset_scenario(socket, true) do
    asset_id = socket.assigns.asset.id
    shocked_asset_ids = AssetScenarioStore.reset(asset_id)
    all_assets = Assets.list_assets_with_scenarios(shocked_asset_ids)
    asset = Assets.get_asset(all_assets, asset_id)
    feed = EventFeed.push_scenario_reset_event(socket.assigns.visible_events, asset)
    EventStore.push_scenario_reset_event(asset)
    review_states = ReviewStore.reset(asset_id)

    socket
    |> assign(:all_assets, all_assets)
    |> assign(:review_states, review_states)
    |> assign(:shocked_asset_ids, shocked_asset_ids)
    |> assign_events(feed.visible_events)
    |> assign_asset(asset)
  end

  defp mark_asset_reviewed(socket) do
    asset = socket.assigns.asset
    review_states = ReviewStore.mark_reviewed(asset.id)
    review_state = ReviewState.state_for(asset.id, review_states)
    feed = EventFeed.push_review_event(socket.assigns.visible_events, asset, review_state)
    EventStore.push_review_event(asset, review_state)

    socket
    |> assign(:review_states, review_states)
    |> assign_events(feed.visible_events)
    |> assign_asset(asset)
  end

  defp escalate_asset_review(socket) do
    asset = socket.assigns.asset
    review_states = ReviewStore.escalate(asset.id)
    review_state = ReviewState.state_for(asset.id, review_states)
    feed = EventFeed.push_review_event(socket.assigns.visible_events, asset, review_state)
    EventStore.push_review_event(asset, review_state)

    socket
    |> assign(:review_states, review_states)
    |> assign_events(feed.visible_events)
    |> assign_asset(asset)
  end

  defp assign_events(socket, events) do
    socket
    |> assign(:event_count, length(events))
    |> assign(:visible_events, events)
    |> stream(:events, events, reset: true)
  end

  def signal_tone("Fresh"), do: :success
  def signal_tone("Deep"), do: :success
  def signal_tone("Delayed"), do: :warning
  def signal_tone("Thin"), do: :warning
  def signal_tone("Stale"), do: :danger
  def signal_tone("Illiquid"), do: :danger
  def signal_tone(_signal), do: :neutral

  def price_shock_button_label(true), do: "Shock applied"
  def price_shock_button_label(false), do: "Apply 12% price shock"

  defp normalize_return_to(nil), do: ~p"/"
  defp normalize_return_to(""), do: ~p"/"

  defp normalize_return_to(return_to) do
    return_to
    |> URI.parse()
    |> internal_dashboard_path()
  end

  defp internal_dashboard_path(%URI{scheme: nil, host: nil, path: "/", query: query}) do
    case query do
      nil -> ~p"/"
      query -> "/?#{query}"
    end
  end

  defp internal_dashboard_path(_uri), do: ~p"/"
end
