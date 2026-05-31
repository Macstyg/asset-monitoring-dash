defmodule AssetMonitoringDashWeb.DashboardLive do
  use AssetMonitoringDashWeb, :live_view

  @event_tick_interval_ms 4_000
  @asset_page_limit 50
  @asset_stream_limit 150

  alias AssetMonitoringDash.ActivityLog
  alias AssetMonitoringDash.Assets
  alias AssetMonitoringDash.AssetScenarioStore
  alias AssetMonitoringDash.EventFeed
  alias AssetMonitoringDash.Money
  alias AssetMonitoringDash.ReviewState
  alias AssetMonitoringDash.ReviewStore
  alias AssetMonitoringDash.RiskRecommendation
  alias AssetMonitoringDashWeb.DashboardLive.Components.AssetMonitor
  alias AssetMonitoringDashWeb.DashboardLive.Components.EventFeed, as: DashboardEventFeed
  alias AssetMonitoringDashWeb.DashboardURLState
  alias AssetMonitoringDashWeb.Formatters
  alias AssetMonitoringDashWeb.UI.Card
  alias AssetMonitoringDashWeb.UI.ThemeSwitch

  @impl true
  def mount(params, _session, socket) do
    shocked_asset_ids = AssetScenarioStore.shocked_asset_ids()
    events = ActivityLog.visible_events()
    review_states = ReviewStore.all_states()
    asset_state = DashboardURLState.from_params(params)

    asset_page =
      load_asset_page(
        asset_state.filters,
        asset_state.sort,
        nil,
        review_states,
        shocked_asset_ids
      )

    snapshot = Assets.portfolio_snapshot(shocked_asset_ids)

    socket =
      socket
      |> stream_configure(:assets, dom_id: &"asset-row-#{&1.dom_id}")
      |> stream_configure(:events, dom_id: &"event-row-#{&1.id}")
      |> assign(:page_title, "Asset Risk Cockpit")
      |> assign(:snapshot, snapshot)
      |> assign(:shocked_asset_ids, shocked_asset_ids)
      |> assign(:scenario_count, MapSet.size(shocked_asset_ids))
      |> assign(:review_states, review_states)
      |> assign_asset_page(asset_page, :reset)
      |> assign(:feed_paused, false)
      |> assign(:next_event_index, 0)
      |> assign(:event_filters, default_event_filters())
      |> assign(:event_history, events)
      |> assign(:event_filter_form, event_filter_form(default_event_filters()))
      |> assign(:event_source_filter_options, event_source_filter_options())
      |> assign(:active_event_filter_chips, active_event_filter_chips(default_event_filters()))
      |> assign(:chain_filter_options, Assets.chain_filter_options())
      |> assign_asset_url_state(asset_state)
      |> assign(:asset_filters, asset_state.filters)
      |> assign(:asset_sort, asset_state.sort)
      |> assign(:asset_sort_options, asset_sort_options())
      |> assign_metric_cards()
      |> assign(:active_filter_chips, active_filter_chips(asset_state.filters))
      |> assign(:filter_form, filter_form(asset_state.filters))
      |> assign(:risk_filter_options, Assets.risk_filter_options())
      |> assign(:action_filter_options, Assets.action_filter_options())
      |> assign(:operator_state_filter_options, Assets.operator_state_filter_options())
      |> stream(
        :assets,
        assets_for_table(asset_page.entries, review_states, shocked_asset_ids)
      )
      |> apply_event_filter()

    schedule_event_tick_for_connection(connected?(socket))

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply, apply_asset_state(socket, DashboardURLState.from_params(params))}
  end

  @impl true
  def handle_event("filter_assets", %{"filters" => params}, socket) do
    filters = Assets.normalize_filters(params, socket.assigns.asset_filters)
    asset_state = DashboardURLState.with_filters(socket.assigns.asset_url_state, filters)

    socket =
      case DashboardURLState.same_filter_params?(asset_state, socket.assigns.asset_url_state) do
        true -> apply_asset_state(socket, asset_state)
        false -> patch_asset_state(socket, asset_state)
      end

    {:noreply, socket}
  end

  @impl true
  def handle_event("reset_asset_filters", _params, socket) do
    {:noreply, patch_asset_state(socket, DashboardURLState.default())}
  end

  @impl true
  def handle_event("reset_asset_scenarios", _params, socket) do
    shocked_assets = shocked_assets(socket.assigns.shocked_asset_ids)
    review_states = reset_review_states(shocked_assets)

    push_scenario_reset_events(shocked_assets)

    shocked_asset_ids = AssetScenarioStore.reset_all()
    events = ActivityLog.visible_events()

    socket =
      socket
      |> assign(:snapshot, Assets.portfolio_snapshot(shocked_asset_ids))
      |> assign(:review_states, review_states)
      |> assign(:shocked_asset_ids, shocked_asset_ids)
      |> assign(:scenario_count, MapSet.size(shocked_asset_ids))
      |> assign(:event_history, events)
      |> assign_metric_cards()
      |> apply_asset_filters(socket.assigns.asset_filters)
      |> apply_event_filter()

    {:noreply, socket}
  end

  @impl true
  def handle_event("load_more_assets", _params, %{assigns: %{asset_next_cursor: nil}} = socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("load_more_assets", _params, socket) do
    page =
      load_asset_page(
        socket.assigns.asset_filters,
        socket.assigns.asset_sort,
        socket.assigns.asset_next_cursor,
        socket.assigns.review_states,
        socket.assigns.shocked_asset_ids
      )

    socket =
      socket
      |> assign_asset_page(page, :append)
      |> stream(
        :assets,
        assets_for_table(
          page.entries,
          socket.assigns.review_states,
          socket.assigns.shocked_asset_ids
        ),
        at: -1,
        limit: -@asset_stream_limit
      )

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_events", %{"event_filters" => params}, socket) do
    filters = normalize_event_filters(params, socket.assigns.event_filters)

    socket =
      socket
      |> assign(:event_filters, filters)
      |> assign(:event_filter_form, event_filter_form(filters))
      |> assign(:active_event_filter_chips, active_event_filter_chips(filters))
      |> apply_event_filter()

    {:noreply, socket}
  end

  @impl true
  def handle_event("sort_assets", %{"field" => field}, socket) do
    socket =
      socket
      |> patch_asset_state(DashboardURLState.next_sort(socket.assigns.asset_url_state, field))

    {:noreply, socket}
  end

  @impl true
  def handle_event("remove_filter_value", %{"filter" => "query"}, socket) do
    filters = %{socket.assigns.asset_filters | query: ""}
    asset_state = DashboardURLState.with_filters(socket.assigns.asset_url_state, filters)

    {:noreply, patch_asset_state(socket, asset_state)}
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
  def handle_event(
        "remove_filter_value",
        %{"filter" => "event_sources", "option" => value},
        socket
      ) do
    filters =
      Map.update!(socket.assigns.event_filters, :sources, fn sources ->
        Enum.reject(sources, &(&1 == value))
      end)

    socket =
      socket
      |> assign(:event_filters, filters)
      |> assign(:event_filter_form, event_filter_form(filters))
      |> assign(:active_event_filter_chips, active_event_filter_chips(filters))
      |> apply_event_filter()

    {:noreply, socket}
  end

  @impl true
  def handle_event("select_asset", %{"id" => asset_id}, socket) do
    {:noreply,
     push_navigate(socket, to: asset_detail_path(asset_id, socket.assigns.asset_url_state))}
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

  defp assign_metric_cards(socket) do
    assign(socket, :metric_cards, metric_cards(socket.assigns.snapshot))
  end

  defp metric_cards(snapshot) do
    [
      %{
        id: "collateral-value-card",
        label: "Collateral value",
        context: "24H",
        value: Formatters.compact_usd(snapshot.total_collateral_value_usd),
        delta: Formatters.signed_percent(snapshot.collateral_delta_percent),
        delta_tone: collateral_delta_tone(snapshot.collateral_delta_percent),
        description: "monitored collateral"
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
        delta: "#{signed_integer(snapshot.risk_delta)} risk",
        delta_tone: delta_tone(snapshot.risk_delta),
        description: "#{String.downcase(snapshot.risk_band)} pressure"
      }
    ]
  end

  defp signed_integer(value) when value > 0, do: "+#{value}"
  defp signed_integer(value), do: Integer.to_string(value)

  defp delta_tone(value) when value > 0, do: :warning
  defp delta_tone(value) when value < 0, do: :positive
  defp delta_tone(_value), do: :neutral

  defp collateral_delta_tone(value) do
    case Decimal.compare(Money.decimal(value), Decimal.new("0")) do
      :gt -> :positive
      :lt -> :negative
      :eq -> :neutral
    end
  end

  defp apply_asset_state(socket, %DashboardURLState{} = asset_state) do
    socket
    |> assign_asset_url_state(asset_state)
    |> assign(:asset_sort, asset_state.sort)
    |> apply_asset_filters(asset_state.filters)
  end

  defp patch_asset_state(socket, %DashboardURLState{} = asset_state) do
    push_patch(socket, to: ~p"/?#{DashboardURLState.params(asset_state)}")
  end

  defp assign_asset_url_state(socket, %DashboardURLState{} = asset_state) do
    socket
    |> assign(:asset_url_state, asset_state)
    |> assign(:asset_view_shared?, DashboardURLState.active?(asset_state))
  end

  defp asset_detail_path(asset_id, %DashboardURLState{} = asset_state) do
    case DashboardURLState.active?(asset_state) do
      true -> ~p"/assets/#{asset_id}?#{%{return_to: asset_monitor_path(asset_state)}}"
      false -> ~p"/assets/#{asset_id}"
    end
  end

  defp asset_monitor_path(%DashboardURLState{} = asset_state) do
    ~p"/?#{DashboardURLState.params(asset_state)}"
  end

  defp apply_asset_filters(socket, filters) do
    page =
      load_asset_page(
        filters,
        socket.assigns.asset_sort,
        nil,
        socket.assigns.review_states,
        socket.assigns.shocked_asset_ids
      )

    socket
    |> assign(:asset_filters, filters)
    |> assign(:active_filter_chips, active_filter_chips(filters))
    |> assign(:filter_form, filter_form(filters))
    |> assign_asset_page(page, :reset)
    |> stream(
      :assets,
      assets_for_table(
        page.entries,
        socket.assigns.review_states,
        socket.assigns.shocked_asset_ids
      ),
      reset: true
    )
  end

  defp load_asset_page(filters, sort, cursor, review_states, shocked_asset_ids) do
    Assets.list_persisted_assets_page(%{
      filters: filters,
      sort: sort,
      cursor: cursor,
      limit: @asset_page_limit,
      review_states: review_states,
      shocked_asset_ids: shocked_asset_ids
    })
  end

  defp assign_asset_page(socket, page, :reset) do
    socket
    |> assign(:asset_count, page.total_count)
    |> assign(:asset_summary, page.summary)
    |> assign(:asset_loaded_count, length(page.entries))
    |> assign(:asset_next_cursor, page.next_cursor)
  end

  defp assign_asset_page(socket, page, :append) do
    socket
    |> assign(:asset_count, page.total_count)
    |> assign(:asset_summary, page.summary)
    |> assign(:asset_loaded_count, socket.assigns.asset_loaded_count + length(page.entries))
    |> assign(:asset_next_cursor, page.next_cursor)
  end

  defp reset_review_states(assets) do
    Enum.reduce(assets, ReviewStore.all_states(), fn asset, _states ->
      review_reset = ReviewStore.reset_after_scenario(asset.id)
      record_review_decision(asset, review_reset.decision)

      review_reset.states
    end)
  end

  defp push_scenario_reset_events(assets) do
    Enum.each(assets, &ActivityLog.record_scenario_reset/1)
  end

  defp shocked_assets(shocked_asset_ids) do
    shocked_asset_ids
    |> Assets.list_persisted_assets_by_ids(shocked_asset_ids)
  end

  defp record_review_decision(_asset, nil), do: :ok

  defp record_review_decision(asset, decision) do
    ActivityLog.record_review_decision(asset, decision)
  end

  defp remove_filter_value(socket, field, value) do
    asset_state =
      socket.assigns.asset_url_state
      |> DashboardURLState.remove_filter_value(field, value)

    patch_asset_state(socket, asset_state)
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

  defp default_event_filters do
    %{sources: [], source_option_query: ""}
  end

  defp event_source_filter_options do
    [
      %{value: "system", label: "System", icon_text: "S", tone: :info},
      %{value: "operator", label: "Operator", icon_text: "O", tone: :success},
      %{value: "scenario", label: "Scenario", icon_text: "Sc", tone: :warning}
    ]
  end

  defp normalize_event_filters(params, current_filters) do
    %{
      sources: normalize_event_source_values(Map.get(params, "sources", current_filters.sources)),
      source_option_query:
        normalize_event_source_query(Map.get(params, "source_option_query", ""))
    }
  end

  defp apply_event_filter(socket) do
    events =
      socket.assigns.event_history
      |> filter_events(socket.assigns.event_filters.sources)
      |> Enum.take(EventFeed.visible_event_limit())

    socket
    |> assign(:event_count, length(events))
    |> assign(:visible_events, events)
    |> stream(:events, events, reset: true)
  end

  defp filter_events(events, []), do: events

  defp filter_events(events, sources) do
    Enum.filter(events, &(event_source_value(&1) in sources))
  end

  defp normalize_event_source_values(values) do
    allowed_values = Enum.map(event_source_filter_options(), & &1.value)

    values
    |> List.wrap()
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.filter(&(&1 in allowed_values))
    |> Enum.uniq()
  end

  defp normalize_event_source_query(nil), do: ""

  defp normalize_event_source_query(query) do
    query
    |> String.trim()
    |> String.downcase()
  end

  defp event_filter_form(filters) do
    to_form(
      %{
        "sources" => filters.sources,
        "source_option_query" => filters.source_option_query
      },
      as: :event_filters
    )
  end

  defp active_event_filter_chips(filters) do
    event_source_filter_options()
    |> Map.new(&{&1.value, &1})
    |> then(fn options_by_value ->
      Enum.map(filters.sources, fn value ->
        option = options_by_value[value]

        option
        |> Map.take([:icon_text, :label, :tone])
        |> Map.merge(%{
          id: "event-sources-#{chip_id(value)}",
          field: "event_sources",
          value: value,
          group: "Source"
        })
      end)
    end)
  end

  defp event_source_value(%{kind: kind}) when is_atom(kind), do: Atom.to_string(kind)
  defp event_source_value(_event), do: "system"

  defp asset_sort_options do
    [
      %{field: "asset", label: "Asset"},
      %{field: "chain", label: "Chain"},
      %{field: "floor", label: "Floor"},
      %{field: "value", label: "Value"},
      %{field: "ltv", label: "LTV"},
      %{field: "risk", label: "Risk"},
      %{field: "operator", label: "Operator"},
      %{field: "action", label: "Action"}
    ]
  end

  defp assets_for_table(assets, review_states, shocked_asset_ids) do
    Enum.map(assets, &asset_for_table(&1, review_states, shocked_asset_ids))
  end

  defp asset_for_table(asset, review_states, shocked_asset_ids) do
    recommendation = RiskRecommendation.recommendation_for(asset)
    review_state = ReviewState.state_for(asset.id, review_states)

    Map.merge(asset, %{
      risk_recommendation: recommendation,
      recommendation_reason: List.first(recommendation.reasons),
      review_state: review_state,
      scenario: scenario_for_asset(asset, shocked_asset_ids)
    })
  end

  defp scenario_for_asset(asset, shocked_asset_ids) do
    case Assets.asset_id_in_set?(asset.id, shocked_asset_ids) do
      true -> %{label: "Price shock", tone: :warning}
      false -> nil
    end
  end

  defp push_demo_event(socket) do
    feed = ActivityLog.record_demo_event(socket.assigns.next_event_index)

    socket
    |> assign(:next_event_index, feed.next_event_index)
    |> assign(:event_history, feed.event_history)
    |> apply_event_filter()
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
