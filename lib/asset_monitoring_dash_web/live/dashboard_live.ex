defmodule AssetMonitoringDashWeb.DashboardLive do
  use AssetMonitoringDashWeb, :live_view

  @asset_page_limit 50
  @asset_stream_limit 150

  alias AssetMonitoringDash.ActivityLog
  alias AssetMonitoringDash.Assets
  alias AssetMonitoringDash.AssetScenarioStore
  alias AssetMonitoringDash.DemoOperations
  alias AssetMonitoringDash.EventFeed
  alias AssetMonitoringDash.Money
  alias AssetMonitoringDash.ReviewState
  alias AssetMonitoringDash.ReviewStore
  alias AssetMonitoringDash.RiskRecommendation
  alias AssetMonitoringDash.Simulator
  alias AssetMonitoringDashWeb.DashboardLive.Components.AssetMonitor
  alias AssetMonitoringDashWeb.DashboardLive.Components.EventFeed, as: DashboardEventFeed
  alias AssetMonitoringDashWeb.DashboardLive.Components.SimulatorStatus
  alias AssetMonitoringDashWeb.DashboardURLState
  alias AssetMonitoringDashWeb.Formatters
  alias AssetMonitoringDashWeb.UI.Card
  alias AssetMonitoringDashWeb.UI.Chart
  alias AssetMonitoringDashWeb.UI.Panel
  alias AssetMonitoringDashWeb.UI.SectionHeader
  alias AssetMonitoringDashWeb.UI.ThemeSwitch

  @impl true
  def mount(params, _session, socket) do
    shocked_asset_ids = AssetScenarioStore.shocked_asset_ids()
    events = ActivityLog.visible_events()
    review_states = ReviewStore.all_states()
    asset_state = DashboardURLState.from_params(params)
    simulator_status = simulator_status()

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
      |> assign_scenario_summary()
      |> assign(:review_states, review_states)
      |> assign_asset_page(asset_page, :reset)
      |> assign(:feed_paused, simulator_status.paused?)
      |> assign(:simulator_status, simulator_status)
      |> assign(:last_simulator_action, nil)
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
      |> assign_risk_pressure_chart()
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

    subscribe_to_simulator(connected?(socket))

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
      |> assign_scenario_summary()
      |> assign(:event_history, events)
      |> assign(:last_simulator_action, nil)
      |> assign_metric_cards()
      |> assign_risk_pressure_chart()
      |> apply_asset_filters(socket.assigns.asset_filters)
      |> apply_event_filter()

    {:noreply, socket}
  end

  @impl true
  def handle_event("reset_demo_runtime", _params, socket) do
    DemoOperations.reset_mutable_state()

    shocked_asset_ids = AssetScenarioStore.shocked_asset_ids()
    review_states = ReviewStore.all_states()
    events = ActivityLog.visible_events()

    socket =
      socket
      |> assign(:snapshot, Assets.portfolio_snapshot(shocked_asset_ids))
      |> assign(:review_states, review_states)
      |> assign(:shocked_asset_ids, shocked_asset_ids)
      |> assign(:scenario_count, MapSet.size(shocked_asset_ids))
      |> assign_scenario_summary()
      |> assign(:event_history, events)
      |> assign_metric_cards()
      |> assign_risk_pressure_chart()
      |> assign_simulator_status()
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
  def handle_event("run_event_tick", _params, socket) do
    {:noreply, run_event_tick(socket)}
  end

  @impl true
  def handle_event("run_scenario_tick", _params, socket) do
    {:noreply, run_scenario_tick(socket)}
  end

  @impl true
  def handle_event("toggle_simulator_process", _params, socket) do
    {:noreply, toggle_simulator_process(socket.assigns.feed_paused, socket)}
  end

  @impl true
  def handle_info({Simulator, :event_recorded, feed}, %{assigns: %{feed_paused: true}} = socket) do
    {:noreply,
     socket
     |> assign(:next_event_index, feed.next_event_index)
     |> assign_last_event_tick(feed)
     |> assign_simulator_status()}
  end

  def handle_info({Simulator, :event_recorded, feed}, socket) do
    {:noreply, apply_demo_feed(socket, feed)}
  end

  def handle_info(
        {Simulator, :scenario_applied, payload},
        %{assigns: %{feed_paused: true}} = socket
      ) do
    {:noreply, apply_simulator_scenario(socket, payload)}
  end

  def handle_info({Simulator, :scenario_applied, payload}, socket) do
    socket =
      socket
      |> assign(:event_history, payload.event_history)
      |> apply_simulator_scenario(payload)
      |> apply_event_filter()

    {:noreply, socket}
  end

  def handle_info({Simulator, :scenario_unavailable, payload}, socket) do
    {:noreply, apply_unavailable_scenario_tick(socket, payload)}
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
    |> assign_event_volume_chart()
    |> stream(:events, events, reset: true)
  end

  defp assign_event_volume_chart(socket) do
    option = event_volume_chart_option(ActivityLog.event_source_buckets())

    socket
    |> assign(:event_volume_chart_option, option)
    |> push_event("chart:update", %{id: "event-volume-chart", option: option})
  end

  defp assign_risk_pressure_chart(socket) do
    option =
      risk_pressure_chart_option(Assets.risk_pressure_buckets(socket.assigns.shocked_asset_ids))

    socket
    |> assign(:risk_pressure_chart_option, option)
    |> push_event("chart:update", %{id: "risk-pressure-chart", option: option})
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

  defp event_volume_chart_option(buckets) do
    source_options = event_source_filter_options()

    %{
      animationDuration: 350,
      grid: %{bottom: 8, containLabel: true, left: 8, right: 8, top: 96},
      legend: %{
        itemHeight: 8,
        itemWidth: 8,
        right: 0,
        textStyle: %{color: "css:--amd-muted", fontFamily: "var(--amd-font-mono)"},
        top: 0
      },
      series: Enum.map(source_options, &event_volume_chart_series(&1, buckets)),
      tooltip: %{
        axisPointer: %{
          lineStyle: %{color: "css:--amd-border", type: "dashed", width: 1},
          type: "line"
        },
        backgroundColor: "css:--amd-surface",
        borderColor: "css:--amd-border",
        borderRadius: 8,
        borderWidth: 1,
        confine: true,
        padding: [10, 12],
        textStyle: %{color: "css:--amd-fg"},
        trigger: "axis"
      },
      xAxis: %{
        axisLabel: %{color: "css:--amd-muted", fontFamily: "var(--amd-font-mono)"},
        axisLine: %{lineStyle: %{color: "css:--amd-border"}},
        axisTick: %{show: false},
        data: Enum.map(buckets, & &1.label),
        type: "category"
      },
      yAxis: %{
        axisLabel: %{color: "css:--amd-muted", fontFamily: "var(--amd-font-mono)"},
        minInterval: 1,
        splitLine: %{lineStyle: %{color: "css:--amd-border", type: "dashed"}},
        type: "value"
      }
    }
  end

  defp event_volume_chart_series(option, buckets) do
    color = event_volume_chart_color(option.tone)

    %{
      itemStyle: %{
        borderRadius: [4, 4, 0, 0],
        color: color
      },
      emphasis: %{
        disabled: true,
        itemStyle: %{color: color, opacity: 1}
      },
      name: option.label,
      stack: "events",
      type: "bar",
      data: Enum.map(buckets, &Map.get(&1.sources, option.value, 0))
    }
  end

  defp risk_pressure_chart_option(buckets) do
    %{
      animationDuration: 350,
      legend: %{
        bottom: 0,
        itemHeight: 8,
        itemWidth: 8,
        textStyle: %{color: "css:--amd-muted", fontFamily: "var(--amd-font-mono)"}
      },
      series: [
        %{
          data: Enum.map(buckets, &risk_pressure_chart_point/1),
          emphasis: %{disabled: true},
          label: %{
            color: "css:--amd-muted",
            fontFamily: "var(--amd-font-mono)",
            formatter: "{b}"
          },
          labelLine: %{lineStyle: %{color: "css:--amd-border"}},
          name: "Collateral",
          radius: ["48%", "72%"],
          type: "pie"
        }
      ],
      tooltip: %{
        backgroundColor: "css:--amd-surface",
        borderColor: "css:--amd-border",
        borderRadius: 8,
        borderWidth: 1,
        confine: true,
        padding: [10, 12],
        textStyle: %{color: "css:--amd-fg"},
        trigger: "item"
      }
    }
  end

  defp risk_pressure_chart_point(bucket) do
    %{
      itemStyle: %{
        color: chart_color(bucket.tone)
      },
      name: bucket.label,
      tooltipValue: Money.format_usd(bucket.collateral_value_usd),
      value: Decimal.to_float(bucket.collateral_value_usd)
    }
  end

  defp chart_color(:success), do: "#4ade80"
  defp chart_color(:warning), do: "#f5b70a"
  defp chart_color(:danger), do: "#f87171"
  defp chart_color(:info), do: "#22c7e6"
  defp chart_color(_tone), do: "#94a3b8"

  defp event_volume_chart_color(tone), do: chart_color(tone)

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
      true -> AssetScenarioStore.scenario_option_for_asset(asset.id)
      false -> nil
    end
  end

  defp run_event_tick(socket) do
    feed = record_demo_event(socket.assigns.next_event_index)

    apply_demo_feed(socket, feed)
  end

  defp run_scenario_tick(socket) do
    case Simulator.scenario_tick() do
      {:error, :not_started} ->
        assign_simulator_status(socket)

      %{asset: _asset} = payload ->
        apply_scenario_tick(socket, payload)

      %{reason: _reason} = payload ->
        apply_unavailable_scenario_tick(socket, payload)

      %{event_history: _event_history} = feed ->
        apply_demo_feed(socket, feed)
    end
  end

  defp apply_unavailable_scenario_tick(socket, payload) do
    socket
    |> assign_last_unavailable_scenario_tick(payload)
    |> assign_simulator_status()
  end

  defp apply_scenario_tick(socket, payload) do
    socket
    |> assign(:event_history, payload.event_history)
    |> apply_simulator_scenario(payload)
    |> apply_event_filter()
  end

  defp apply_demo_feed(socket, feed) do
    socket
    |> assign(:next_event_index, feed.next_event_index)
    |> assign(:event_history, feed.event_history)
    |> assign_last_event_tick(feed)
    |> assign_simulator_status()
    |> apply_event_filter()
  end

  defp apply_simulator_scenario(socket, payload) do
    shocked_asset_ids = payload.shocked_asset_ids

    socket
    |> assign(:next_event_index, payload.next_event_index)
    |> assign_last_scenario_tick(payload)
    |> assign(:snapshot, Assets.portfolio_snapshot(shocked_asset_ids))
    |> assign(:review_states, simulator_review_states(payload))
    |> assign(:shocked_asset_ids, shocked_asset_ids)
    |> assign(:scenario_count, MapSet.size(shocked_asset_ids))
    |> assign_scenario_summary()
    |> assign_metric_cards()
    |> assign_risk_pressure_chart()
    |> assign_simulator_status()
    |> apply_asset_filters(socket.assigns.asset_filters)
  end

  defp simulator_review_states(%{review_states: review_states}), do: review_states
  defp simulator_review_states(_payload), do: ReviewStore.all_states()

  defp assign_last_event_tick(socket, %{event_history: [event | _events]}) do
    assign(socket, :last_simulator_action, %{
      context: event.chain || event.status,
      detail: event.detail,
      label: "Event tick",
      timestamp: simulator_action_time(event.occurred_at),
      title: event.title,
      tone: event.tone
    })
  end

  defp assign_last_event_tick(socket, _feed), do: socket

  defp assign_last_scenario_tick(socket, %{asset: asset} = payload) do
    scenario = scenario_for_payload(payload)

    assign(socket, :last_simulator_action, %{
      context: asset.chain,
      detail: scenario_detail(asset, scenario),
      label: "Scenario tick",
      timestamp: simulator_action_time(DateTime.utc_now(:second)),
      title: scenario_title(scenario),
      tone: scenario_tone(scenario)
    })
  end

  defp assign_last_unavailable_scenario_tick(socket, payload) do
    assign(socket, :last_simulator_action, %{
      context: "Scenario controls",
      detail: unavailable_scenario_detail(payload.reason),
      label: "Scenario tick",
      timestamp: simulator_action_time(DateTime.utc_now(:second)),
      title: "Scenario not applied",
      tone: :warning
    })
  end

  defp unavailable_scenario_detail(:scenario_cap_reached) do
    "Scenario cap reached. Reset runtime or clear active scenarios before applying another scenario."
  end

  defp unavailable_scenario_detail(:no_candidate_assets) do
    "No eligible moderate or elevated assets remain for a scenario tick."
  end

  defp unavailable_scenario_detail(_reason), do: "Scenario tick could not find an eligible asset."

  defp scenario_for_payload(%{scenario_id: scenario_id}) do
    AssetScenarioStore.scenario_option_for(scenario_id)
  end

  defp scenario_for_payload(%{asset: asset}) do
    AssetScenarioStore.scenario_option_for_asset(asset.id)
  end

  defp scenario_title(%{label: label}), do: label
  defp scenario_title(_scenario), do: "Scenario applied"

  defp scenario_detail(asset, %{description: description}) do
    "#{asset.name} · #{description}"
  end

  defp scenario_detail(asset, _scenario), do: "#{asset.name} scenario updated."

  defp scenario_tone(%{tone: tone}), do: tone
  defp scenario_tone(_scenario), do: :neutral

  defp simulator_action_time(nil), do: "now"

  defp simulator_action_time(datetime) do
    datetime
    |> DateTime.truncate(:second)
    |> Calendar.strftime("%H:%M:%S UTC")
  end

  defp assign_scenario_summary(socket) do
    assign(socket, :scenario_summary, AssetScenarioStore.active_summary())
  end

  defp toggle_simulator_process(true, socket) do
    Simulator.resume()

    socket
    |> assign(:feed_paused, false)
    |> assign(:event_history, ActivityLog.visible_events())
    |> assign_simulator_status()
    |> apply_event_filter()
  end

  defp toggle_simulator_process(false, socket) do
    Simulator.pause()

    socket
    |> assign(:feed_paused, true)
    |> assign_simulator_status()
  end

  defp record_demo_event(next_event_index) do
    case Simulator.event_tick() do
      {:error, :not_started} -> ActivityLog.record_demo_event(next_event_index)
      feed -> feed
    end
  end

  defp simulator_status do
    case Simulator.status() do
      %{paused?: _paused?} = status ->
        Map.put(status, :running?, true)

      {:error, :not_started} ->
        %{
          interval_ms: nil,
          max_active_scenarios: 0,
          next_event_index: 0,
          paused?: false,
          running?: false,
          scenario_every: nil,
          tick_index: 0
        }
    end
  end

  defp assign_simulator_status(socket), do: assign(socket, :simulator_status, simulator_status())

  defp subscribe_to_simulator(true), do: Simulator.subscribe()
  defp subscribe_to_simulator(false), do: :ok
end
