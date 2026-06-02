defmodule AssetMonitoringDashWeb.AssetLive do
  use AssetMonitoringDashWeb, :live_view

  alias AssetMonitoringDash.ActivityLog
  alias AssetMonitoringDash.Assets
  alias AssetMonitoringDash.AssetScenarioStore
  alias AssetMonitoringDash.DemoOperations
  alias AssetMonitoringDash.ReviewState
  alias AssetMonitoringDash.ReviewStore
  alias AssetMonitoringDash.Simulator
  alias AssetMonitoringDashWeb.AssetDetailURLState
  alias AssetMonitoringDashWeb.AssetLive.AssetEventFilters
  alias AssetMonitoringDashWeb.AssetLive.Components.AssetActivity
  alias AssetMonitoringDashWeb.AssetLive.Components.AssetContextStrip
  alias AssetMonitoringDashWeb.AssetLive.Components.AssetInspection
  alias AssetMonitoringDashWeb.AssetLive.Components.DecisionRail
  alias AssetMonitoringDashWeb.AssetLive.Components.RelatedAssets
  alias AssetMonitoringDashWeb.AssetLive.Components.ReviewHistory
  alias AssetMonitoringDashWeb.AssetLive.ReviewAction
  alias AssetMonitoringDashWeb.AssetLive.ViewModel
  alias AssetMonitoringDashWeb.UI.Badge
  alias AssetMonitoringDashWeb.UI.Tabs

  @impl true
  def mount(%{"id" => asset_id} = params, _session, socket) do
    shocked_asset_ids = AssetScenarioStore.shocked_asset_ids()
    detail_state = AssetDetailURLState.from_params(params)
    event_filters = detail_state.event_filters

    socket =
      socket
      |> stream_configure(:events, dom_id: &"asset-event-row-#{&1.id}")
      |> assign(:page_title, "Asset detail")
      |> assign(:review_states, ReviewStore.all_states())
      |> assign(:shocked_asset_ids, shocked_asset_ids)
      |> assign(:return_to, normalize_return_to(Map.get(params, "return_to")))
      |> assign(:visible_events, [])
      |> assign(:event_count, 0)
      |> assign(:asset_detail_url_state, detail_state)
      |> assign(:asset_detail_focus, detail_state.focus)
      |> assign(:asset_detail_focus_options, asset_detail_focus_options())
      |> assign(:asset_event_source_filter_options, AssetEventFilters.options())
      |> assign(:scenario_options, AssetScenarioStore.scenario_options())
      |> assign(:review_reason_options, ReviewAction.options())
      |> assign(:review_action_form, ReviewAction.form())
      |> AssetEventFilters.assign_state(event_filters)
      |> stream(:events, [])
      |> assign_asset_from_id(asset_id)

    subscribe_to_simulator(connected?(socket))

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => asset_id} = params, _uri, socket) do
    detail_state = AssetDetailURLState.from_params(params)

    socket =
      socket
      |> assign(:return_to, normalize_return_to(Map.get(params, "return_to")))
      |> assign(:asset_detail_url_state, detail_state)
      |> assign(:asset_detail_focus, detail_state.focus)
      |> AssetEventFilters.assign_state(detail_state.event_filters)
      |> assign_asset_from_id(asset_id)

    {:noreply, socket}
  end

  @impl true
  def handle_event("apply_price_shock", _params, socket) do
    {:noreply, apply_asset_scenario(socket, "price_shock", socket.assigns.asset_shocked?)}
  end

  @impl true
  def handle_event("apply_asset_scenario", %{"scenario" => scenario_id}, socket) do
    {:noreply, apply_asset_scenario(socket, scenario_id, socket.assigns.asset_shocked?)}
  end

  @impl true
  def handle_event("reset_asset_scenario", _params, socket) do
    {:noreply, reset_asset_scenario(socket, socket.assigns.asset_shocked?)}
  end

  @impl true
  def handle_event("validate_review_action", %{"review_action" => params}, socket) do
    {:noreply, assign(socket, :review_action_form, ReviewAction.form(params))}
  end

  @impl true
  def handle_event(
        "submit_review_action",
        %{"review_action" => %{"action" => "reviewed"} = params},
        socket
      ) do
    {:noreply, mark_asset_reviewed(socket, ReviewAction.audit_context(params))}
  end

  @impl true
  def handle_event(
        "submit_review_action",
        %{"review_action" => %{"action" => "escalated"} = params},
        socket
      ) do
    {:noreply, escalate_asset_review(socket, ReviewAction.audit_context(params))}
  end

  @impl true
  def handle_event("filter_asset_events", %{"asset_event_filters" => params}, socket) do
    filters = AssetEventFilters.normalize(params)

    detail_state =
      AssetDetailURLState.with_event_filters(socket.assigns.asset_detail_url_state, filters)

    socket =
      update_asset_detail_state(socket, detail_state, filters)

    {:noreply, socket}
  end

  @impl true
  def handle_event("focus_asset_section", %{"tab" => section}, socket) do
    detail_state = AssetDetailURLState.with_focus(socket.assigns.asset_detail_url_state, section)

    socket =
      case AssetDetailURLState.same_url_params?(
             detail_state,
             socket.assigns.asset_detail_url_state
           ) do
        true -> assign(socket, :asset_detail_focus, detail_state.focus)
        false -> patch_asset_detail_state(socket, detail_state)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event(
        "remove_filter_value",
        %{"filter" => "asset_event_sources", "option" => value},
        socket
      ) do
    filters =
      Map.update!(socket.assigns.asset_event_filters, :sources, fn sources ->
        Enum.reject(sources, &(&1 == value))
      end)

    detail_state =
      AssetDetailURLState.with_event_filters(socket.assigns.asset_detail_url_state, filters)

    socket =
      update_asset_detail_state(socket, detail_state, filters)

    {:noreply, socket}
  end

  @impl true
  def handle_info({Simulator, :scenario_applied, payload}, socket) do
    {:noreply,
     refresh_asset_from_scenario(socket, scenario_payload_relevant?(socket, payload), payload)}
  end

  def handle_info({Simulator, :event_recorded, feed}, socket) do
    {:noreply, refresh_asset_events(socket, feed_relevant?(socket, feed))}
  end

  defp assign_asset_from_id(socket, asset_id) do
    asset =
      Assets.get_persisted_asset_with_scenarios(asset_id, socket.assigns.shocked_asset_ids)

    assign_asset(socket, asset)
  end

  defp assign_asset(socket, nil) do
    socket
    |> put_flash(:error, "Asset not found")
    |> push_navigate(to: ~p"/")
  end

  defp assign_asset(socket, asset) do
    view_model =
      ViewModel.build(asset,
        review_states: socket.assigns.review_states,
        shocked_asset_ids: socket.assigns.shocked_asset_ids
      )

    socket
    |> assign(ViewModel.assigns(view_model))
    |> assign_asset_events(asset.id)
  end

  defp apply_asset_scenario(socket, _scenario_id, true), do: socket

  defp apply_asset_scenario(socket, scenario_id, false) do
    asset_id = socket.assigns.asset.id
    scenario = DemoOperations.apply_scenario(asset_id, scenario_id)

    socket
    |> assign(:review_states, scenario.review_states)
    |> assign(:shocked_asset_ids, scenario.shocked_asset_ids)
    |> assign_asset(scenario.asset)
  end

  defp reset_asset_scenario(socket, false), do: socket

  defp reset_asset_scenario(socket, true) do
    asset_id = socket.assigns.asset.id
    shocked_asset_ids = AssetScenarioStore.reset(asset_id)
    asset = Assets.get_persisted_asset_with_scenarios(asset_id, shocked_asset_ids)
    ActivityLog.record_scenario_reset(asset)
    review_reset = ReviewStore.reset_after_scenario(asset_id)
    record_review_decision(asset, review_reset.decision)

    socket
    |> assign(:review_states, review_reset.states)
    |> assign(:shocked_asset_ids, shocked_asset_ids)
    |> assign_asset(asset)
  end

  defp mark_asset_reviewed(socket, audit_context) do
    asset = socket.assigns.asset
    review_states = ReviewStore.mark_reviewed(asset.id, audit_context)
    review_state = ReviewState.state_for(asset.id, review_states)
    ActivityLog.record_review(asset, review_state, audit_context)

    socket
    |> assign(:review_states, review_states)
    |> assign(:review_action_form, ReviewAction.form())
    |> assign_asset(asset)
  end

  defp escalate_asset_review(socket, audit_context) do
    asset = socket.assigns.asset
    review_states = ReviewStore.escalate(asset.id, audit_context)
    review_state = ReviewState.state_for(asset.id, review_states)
    ActivityLog.record_review(asset, review_state, audit_context)

    socket
    |> assign(:review_states, review_states)
    |> assign(:review_action_form, ReviewAction.form())
    |> assign_asset(asset)
  end

  defp record_review_decision(_asset, nil), do: :ok

  defp record_review_decision(asset, decision) do
    ActivityLog.record_review_decision(asset, decision)
  end

  defp assign_asset_events(socket, asset_id) do
    events =
      asset_id
      |> ActivityLog.visible_events_for_asset()
      |> AssetEventFilters.filter_events(socket.assigns.asset_event_filters.sources)

    assign_events(socket, events)
  end

  defp assign_events(socket, events) do
    socket
    |> assign(:event_count, length(events))
    |> assign(:visible_events, events)
    |> stream(:events, events, reset: true)
  end

  defp refresh_asset_from_scenario(socket, true, payload) do
    socket
    |> assign(:review_states, simulator_review_states(payload))
    |> assign(:shocked_asset_ids, payload.shocked_asset_ids)
    |> assign_asset_from_id(socket.assigns.asset.id)
  end

  defp refresh_asset_from_scenario(socket, false, _payload), do: socket

  defp simulator_review_states(%{review_states: review_states}), do: review_states
  defp simulator_review_states(_payload), do: ReviewStore.all_states()

  defp refresh_asset_events(socket, true),
    do: assign_asset_events(socket, socket.assigns.asset.id)

  defp refresh_asset_events(socket, false), do: socket

  defp scenario_payload_relevant?(socket, %{asset: %{id: asset_id}}) do
    Assets.same_asset_id?(asset_id, socket.assigns.asset.id)
  end

  defp scenario_payload_relevant?(_socket, _payload), do: false

  defp feed_relevant?(socket, %{event_history: events}) do
    Enum.any?(events, &event_relevant?(&1, socket.assigns.asset.id))
  end

  defp feed_relevant?(_socket, _feed), do: false

  defp event_relevant?(%{asset_id: asset_id}, current_asset_id) when is_binary(asset_id) do
    Assets.same_asset_id?(asset_id, current_asset_id)
  end

  defp event_relevant?(_event, _current_asset_id), do: false

  defp update_asset_detail_state(socket, %AssetDetailURLState{} = detail_state, filters) do
    current_detail_state = socket.assigns.asset_detail_url_state

    socket =
      socket
      |> assign(:asset_detail_url_state, detail_state)
      |> assign(:asset_detail_focus, detail_state.focus)
      |> AssetEventFilters.assign_state(filters)
      |> assign_asset_events(socket.assigns.asset.id)

    case AssetDetailURLState.same_url_params?(detail_state, current_detail_state) do
      true -> socket
      false -> patch_asset_detail_state(socket, detail_state)
    end
  end

  defp patch_asset_detail_state(socket, %AssetDetailURLState{} = detail_state) do
    push_patch(
      socket,
      to: asset_detail_path(socket.assigns.asset.id, socket.assigns.return_to, detail_state)
    )
  end

  defp asset_detail_focus_options do
    [
      %{value: "overview", label: "Overview"},
      %{value: "activity", label: "Activity"},
      %{value: "related", label: "Related"}
    ]
  end

  defp asset_detail_path(asset_id, return_to, %AssetDetailURLState{} = detail_state) do
    params =
      detail_state
      |> AssetDetailURLState.params()
      |> put_return_to_param(return_to)

    case params do
      empty when empty == %{} -> ~p"/assets/#{asset_id}"
      params -> ~p"/assets/#{asset_id}?#{params}"
    end
  end

  defp put_return_to_param(params, "/"), do: params
  defp put_return_to_param(params, return_to), do: Map.put(params, "return_to", return_to)

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

  defp subscribe_to_simulator(true), do: Simulator.subscribe()
  defp subscribe_to_simulator(false), do: :ok
end
