defmodule AssetMonitoringDashWeb.AssetLive do
  use AssetMonitoringDashWeb, :live_view

  alias AssetMonitoringDash.ActivityLog
  alias AssetMonitoringDash.Assets
  alias AssetMonitoringDash.AssetScenarioStore
  alias AssetMonitoringDash.ReviewAudit
  alias AssetMonitoringDash.ReviewState
  alias AssetMonitoringDash.ReviewStore
  alias AssetMonitoringDash.Risk
  alias AssetMonitoringDash.RiskRecommendation
  alias AssetMonitoringDashWeb.AssetDetailURLState
  alias AssetMonitoringDashWeb.DashboardComponents.AssetActivity
  alias AssetMonitoringDashWeb.DashboardComponents.AssetContextStrip
  alias AssetMonitoringDashWeb.DashboardComponents.AssetInspection
  alias AssetMonitoringDashWeb.DashboardComponents.InvestigationBrief
  alias AssetMonitoringDashWeb.DashboardComponents.RelatedAssets
  alias AssetMonitoringDashWeb.DashboardComponents.ReviewActionForm
  alias AssetMonitoringDashWeb.DashboardComponents.ReviewHistory
  alias AssetMonitoringDashWeb.Formatters
  alias AssetMonitoringDashWeb.UI.Badge
  alias AssetMonitoringDashWeb.UI.Button
  alias AssetMonitoringDashWeb.UI.Card
  alias AssetMonitoringDashWeb.UI.Tabs

  @related_asset_limit 4
  @default_review_reason "signal_reviewed"

  @impl true
  def mount(%{"id" => asset_id} = params, _session, socket) do
    shocked_asset_ids = AssetScenarioStore.shocked_asset_ids()
    assets = Assets.list_assets_with_scenarios(shocked_asset_ids)
    detail_state = AssetDetailURLState.from_params(params)
    event_filters = detail_state.event_filters

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
      |> assign(:asset_detail_url_state, detail_state)
      |> assign(:asset_detail_focus, detail_state.focus)
      |> assign(:asset_detail_focus_options, asset_detail_focus_options())
      |> assign(:asset_event_source_filter_options, asset_event_source_filter_options())
      |> assign(:review_reason_options, review_reason_options())
      |> assign(:review_action_form, review_action_form(default_review_action_params()))
      |> assign_asset_event_filter_state(event_filters)
      |> stream(:events, [])
      |> assign_asset_from_id(asset_id)

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
      |> assign_asset_event_filter_state(detail_state.event_filters)
      |> assign_asset_from_id(asset_id)

    {:noreply, socket}
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
  def handle_event("validate_review_action", %{"review_action" => params}, socket) do
    {:noreply, assign(socket, :review_action_form, review_action_form(params))}
  end

  @impl true
  def handle_event(
        "submit_review_action",
        %{"review_action" => %{"action" => "reviewed"} = params},
        socket
      ) do
    {:noreply, mark_asset_reviewed(socket, review_audit_context(params))}
  end

  @impl true
  def handle_event(
        "submit_review_action",
        %{"review_action" => %{"action" => "escalated"} = params},
        socket
      ) do
    {:noreply, escalate_asset_review(socket, review_audit_context(params))}
  end

  @impl true
  def handle_event("filter_asset_events", %{"asset_event_filters" => params}, socket) do
    filters = normalize_asset_event_filters(params)

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
    |> assign(:review_history, ReviewStore.history_for(asset.id))
    |> assign(:related_assets, related_assets(asset, socket.assigns.all_assets))
    |> assign_asset_events(asset.id)
  end

  defp apply_price_shock(socket, true), do: socket

  defp apply_price_shock(socket, false) do
    asset_id = socket.assigns.asset.id
    shocked_asset_ids = AssetScenarioStore.apply_price_shock(asset_id)
    all_assets = Assets.list_assets_with_scenarios(shocked_asset_ids)
    asset = Assets.get_asset(all_assets, asset_id)
    ActivityLog.record_price_shock(asset, 12)
    review_states = ReviewStore.reset(asset_id)

    socket
    |> assign(:all_assets, all_assets)
    |> assign(:review_states, review_states)
    |> assign(:shocked_asset_ids, shocked_asset_ids)
    |> assign_asset(asset)
  end

  defp reset_asset_scenario(socket, false), do: socket

  defp reset_asset_scenario(socket, true) do
    asset_id = socket.assigns.asset.id
    shocked_asset_ids = AssetScenarioStore.reset(asset_id)
    all_assets = Assets.list_assets_with_scenarios(shocked_asset_ids)
    asset = Assets.get_asset(all_assets, asset_id)
    ActivityLog.record_scenario_reset(asset)
    review_states = ReviewStore.reset(asset_id)

    socket
    |> assign(:all_assets, all_assets)
    |> assign(:review_states, review_states)
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
    |> assign(:review_action_form, review_action_form(default_review_action_params()))
    |> assign_asset(asset)
  end

  defp escalate_asset_review(socket, audit_context) do
    asset = socket.assigns.asset
    review_states = ReviewStore.escalate(asset.id, audit_context)
    review_state = ReviewState.state_for(asset.id, review_states)
    ActivityLog.record_review(asset, review_state, audit_context)

    socket
    |> assign(:review_states, review_states)
    |> assign(:review_action_form, review_action_form(default_review_action_params()))
    |> assign_asset(asset)
  end

  defp assign_asset_events(socket, asset_id) do
    events =
      asset_id
      |> ActivityLog.visible_events_for_asset()
      |> filter_events(socket.assigns.asset_event_filters.sources)

    assign_events(socket, events)
  end

  defp assign_events(socket, events) do
    socket
    |> assign(:event_count, length(events))
    |> assign(:visible_events, events)
    |> stream(:events, events, reset: true)
  end

  defp assign_asset_event_filter_state(socket, filters) do
    socket
    |> assign(:asset_event_filters, filters)
    |> assign(:asset_event_filter_form, asset_event_filter_form(filters))
    |> assign(:active_asset_event_filter_chips, active_asset_event_filter_chips(filters))
  end

  defp update_asset_detail_state(socket, %AssetDetailURLState{} = detail_state, filters) do
    current_detail_state = socket.assigns.asset_detail_url_state

    socket =
      socket
      |> assign(:asset_detail_url_state, detail_state)
      |> assign(:asset_detail_focus, detail_state.focus)
      |> assign_asset_event_filter_state(filters)
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

  defp filter_events(events, []), do: events

  defp filter_events(events, sources) do
    Enum.filter(events, &(Map.get(&1, :source_value, event_source_value(&1)) in sources))
  end

  defp asset_event_source_filter_options do
    [
      %{value: "scenario", label: "Scenario", icon_text: "Sc", tone: :warning},
      %{value: "operator", label: "Operator", icon_text: "O", tone: :success}
    ]
  end

  defp asset_detail_focus_options do
    [
      %{value: "overview", label: "Overview"},
      %{value: "activity", label: "Activity"},
      %{value: "related", label: "Related"}
    ]
  end

  defp normalize_asset_event_filters(params) do
    %{
      sources: Map.get(params, "sources") || Map.get(params, :sources),
      source_option_query:
        Map.get(params, "source_option_query") || Map.get(params, :source_option_query)
    }
    |> AssetDetailURLState.new()
    |> Map.fetch!(:event_filters)
  end

  defp asset_event_filter_form(filters) do
    to_form(
      %{
        "sources" => filters.sources,
        "source_option_query" => filters.source_option_query
      },
      as: :asset_event_filters
    )
  end

  defp active_asset_event_filter_chips(filters) do
    asset_event_source_filter_options()
    |> Map.new(&{&1.value, &1})
    |> then(fn options_by_value ->
      Enum.map(filters.sources, fn value ->
        option = options_by_value[value]

        option
        |> Map.take([:icon_text, :label, :tone])
        |> Map.merge(%{
          id: "asset-event-sources-#{chip_id(value)}",
          field: "asset_event_sources",
          value: value,
          group: "Source"
        })
      end)
    end)
  end

  defp event_source_value(%{kind: kind}) when is_atom(kind), do: Atom.to_string(kind)
  defp event_source_value(_event), do: "system"

  defp chip_id(value) do
    value
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9_-]/, "-")
  end

  defp related_assets(asset, all_assets) do
    all_assets
    |> Enum.filter(&canonical_asset?/1)
    |> Enum.reject(&(&1.id == asset.id))
    |> Enum.map(&{related_asset_score(asset, &1), &1})
    |> Enum.reject(fn {score, _asset} -> score == 0 end)
    |> Enum.sort_by(fn {score, related_asset} ->
      {-score, -related_asset.risk_score, related_asset.name}
    end)
    |> Enum.take(@related_asset_limit)
    |> Enum.map(fn {_score, related_asset} -> related_asset end)
  end

  defp related_asset_score(asset, related_asset) do
    chain_match_score(asset, related_asset) +
      ecosystem_match_score(asset, related_asset) +
      risk_band_match_score(asset, related_asset)
  end

  defp canonical_asset?(%{id: id}), do: !String.contains?(id, "-variant-")

  defp chain_match_score(%{chain: chain}, %{chain: chain}), do: 3
  defp chain_match_score(_asset, _related_asset), do: 0

  defp ecosystem_match_score(%{ecosystem: ecosystem}, %{ecosystem: ecosystem}), do: 2
  defp ecosystem_match_score(_asset, _related_asset), do: 0

  defp risk_band_match_score(%{risk_band: risk_band}, %{risk_band: risk_band}), do: 1
  defp risk_band_match_score(_asset, _related_asset), do: 0

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

  defp default_review_action_params do
    %{"reason" => @default_review_reason, "note" => ""}
  end

  defp review_action_form(params) do
    to_form(
      %{
        "reason" => review_reason_value(Map.get(params, "reason")),
        "note" => review_note(Map.get(params, "note"))
      },
      as: :review_action
    )
  end

  defp review_audit_context(params) do
    ReviewAudit.new(%{
      reason: review_reason_label(Map.get(params, "reason")),
      note: review_note(Map.get(params, "note"))
    })
  end

  defp review_reason_options do
    [
      {"Signal reviewed", "signal_reviewed"},
      {"Oracle checked", "oracle_checked"},
      {"Liquidity checked", "liquidity_checked"},
      {"Borrower follow-up", "borrower_follow_up"}
    ]
  end

  defp review_reason_value(reason) do
    allowed_values = Enum.map(review_reason_options(), fn {_label, value} -> value end)

    case reason in allowed_values do
      true -> reason
      false -> @default_review_reason
    end
  end

  defp review_reason_label(reason) do
    reason = review_reason_value(reason)

    review_reason_options()
    |> Enum.find_value(fn
      {label, ^reason} -> label
      {_label, _value} -> nil
    end)
  end

  defp review_note(nil), do: ""

  defp review_note(note) do
    note
    |> String.trim()
    |> String.slice(0, 180)
  end

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
