defmodule AssetMonitoringDashWeb.DashboardLive do
  use AssetMonitoringDashWeb, :live_view

  @asset_page_limit 50
  @asset_stream_limit 150
  @default_analytics_window :demo
  @analytics_window_options [
    %{
      value: :demo,
      label: "Demo",
      event_bucket_count: 6,
      event_bucket_seconds: 15,
      event_window_label: "90s window",
      portfolio_window_label: "7 points"
    },
    %{
      value: :recent,
      label: "Recent",
      event_bucket_count: 12,
      event_bucket_seconds: 15,
      event_window_label: "3m window",
      portfolio_window_label: "7 points"
    },
    %{
      value: :full,
      label: "Full",
      event_bucket_count: 12,
      event_bucket_seconds: 60,
      event_window_label: "12m window",
      portfolio_window_label: "7 points"
    }
  ]

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
  alias AssetMonitoringDashWeb.ChartOptions
  alias AssetMonitoringDashWeb.DashboardLive.Components.AssetMonitor
  alias AssetMonitoringDashWeb.DashboardLive.Components.EventFeed, as: DashboardEventFeed
  alias AssetMonitoringDashWeb.DashboardLive.Components.SimulatorStatus
  alias AssetMonitoringDashWeb.DashboardURLState
  alias AssetMonitoringDashWeb.Formatters
  alias AssetMonitoringDashWeb.UI.Button
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
      |> assign_analytics_window(@default_analytics_window)
      |> assign_metric_cards()
      |> assign_portfolio_value_chart()
      |> assign_portfolio_risk_chart()
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
      |> assign_portfolio_value_chart()
      |> assign_portfolio_risk_chart()
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
      |> assign_portfolio_value_chart()
      |> assign_portfolio_risk_chart()
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
  def handle_event("set_analytics_window", %{"window" => window}, socket) do
    socket =
      socket
      |> assign_analytics_window(window)
      |> assign_portfolio_value_chart()
      |> assign_portfolio_risk_chart()
      |> assign_event_volume_chart()

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

  attr :id, :string, required: true
  attr :items, :list, required: true

  defp analytics_summary(assigns) do
    ~H"""
    <dl
      id={@id}
      class="mt-4 grid gap-2 border-y border-app-border py-3 sm:grid-cols-3"
    >
      <div
        :for={item <- @items}
        id={"#{@id}-#{item.id}"}
        class="min-w-0 rounded-app bg-app-surface-2 px-3 py-2 ring-1 ring-app-border/70"
      >
        <dt class="font-mono text-[0.68rem] font-semibold uppercase tracking-[0.18em] text-app-muted">
          {item.label}
        </dt>
        <dd class={["mt-1 truncate text-sm font-semibold", analytics_summary_tone(item[:tone])]}>
          {item.value}
        </dd>
      </div>
    </dl>
    """
  end

  defp analytics_summary_tone(:positive), do: "text-app-accent"
  defp analytics_summary_tone(:negative), do: "text-app-danger"
  defp analytics_summary_tone(:warning), do: "text-app-warn"
  defp analytics_summary_tone(_tone), do: "text-app-fg"

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :tone, :atom, default: :neutral

  defp analytics_interpretation(assigns) do
    ~H"""
    <div
      id={@id}
      class={[
        "mt-4 inline-flex max-w-full items-center gap-2 rounded-full px-3 py-1.5 text-xs font-semibold ring-1",
        analytics_interpretation_tone(@tone)
      ]}
    >
      <span class="size-1.5 rounded-full bg-current"></span>
      <span class="truncate">{@label}</span>
    </div>
    """
  end

  defp analytics_interpretation_tone(:positive),
    do: "bg-app-accent/10 text-app-accent ring-app-accent/20"

  defp analytics_interpretation_tone(:negative),
    do: "bg-app-danger/10 text-app-danger ring-app-danger/25"

  defp analytics_interpretation_tone(:warning),
    do: "bg-app-warn/10 text-app-warn ring-app-warn/25"

  defp analytics_interpretation_tone(:info),
    do: "bg-app-accent-2/10 text-app-accent-2 ring-app-accent-2/20"

  defp analytics_interpretation_tone(_tone), do: "bg-app-surface-2 text-app-muted ring-app-border"

  defp assign_metric_cards(socket) do
    assign(socket, :metric_cards, metric_cards(socket.assigns.snapshot))
  end

  defp assign_analytics_window(socket, window) do
    analytics_window = normalize_analytics_window(window)
    option = analytics_window_option(analytics_window)

    socket
    |> assign(:analytics_window, analytics_window)
    |> assign(:analytics_window_options, @analytics_window_options)
    |> assign(:event_window_label, option.event_window_label)
    |> assign(:portfolio_window_label, option.portfolio_window_label)
  end

  defp normalize_analytics_window(:demo), do: :demo
  defp normalize_analytics_window(:recent), do: :recent
  defp normalize_analytics_window(:full), do: :full
  defp normalize_analytics_window("demo"), do: :demo
  defp normalize_analytics_window("recent"), do: :recent
  defp normalize_analytics_window("full"), do: :full
  defp normalize_analytics_window(_window), do: @default_analytics_window

  defp analytics_window_option(window) do
    Enum.find(@analytics_window_options, &(&1.value == window)) ||
      analytics_window_option(@default_analytics_window)
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
    window = analytics_window_option(socket.assigns.analytics_window)

    buckets =
      ActivityLog.event_source_buckets(
        bucket_count: window.event_bucket_count,
        bucket_seconds: window.event_bucket_seconds
      )

    option = ChartOptions.event_volume(buckets, event_source_filter_options())

    socket
    |> assign(:event_volume_empty?, event_volume_empty?(buckets))
    |> assign(:event_volume_interpretation, event_volume_interpretation(buckets))
    |> assign(:event_volume_summary, event_volume_summary(buckets, window))
    |> assign(:event_volume_chart_option, option)
    |> push_event("chart:update", %{id: "event-volume-chart", option: option})
  end

  defp assign_risk_pressure_chart(socket) do
    buckets = Assets.risk_pressure_buckets(socket.assigns.shocked_asset_ids)
    option = ChartOptions.risk_pressure(buckets)

    socket
    |> assign(:risk_pressure_interpretation, risk_pressure_interpretation(buckets))
    |> assign(:risk_pressure_summary, risk_pressure_summary(buckets))
    |> assign(:risk_pressure_chart_option, option)
    |> push_event("chart:update", %{id: "risk-pressure-chart", option: option})
  end

  defp assign_portfolio_value_chart(socket) do
    points =
      Assets.portfolio_value_trend(
        socket.assigns.shocked_asset_ids,
        socket.assigns.analytics_window
      )

    option = ChartOptions.portfolio_value_trend(points)

    socket
    |> assign(:portfolio_value_interpretation, portfolio_value_interpretation(points))
    |> assign(:portfolio_value_summary, portfolio_value_summary(points))
    |> assign(:portfolio_value_chart_option, option)
    |> push_event("chart:update", %{id: "portfolio-value-chart", option: option})
  end

  defp assign_portfolio_risk_chart(socket) do
    points =
      Assets.portfolio_risk_trend(
        socket.assigns.shocked_asset_ids,
        socket.assigns.analytics_window
      )

    option = ChartOptions.portfolio_risk_trend(points)

    socket
    |> assign(:portfolio_risk_interpretation, portfolio_risk_interpretation(points))
    |> assign(:portfolio_risk_summary, portfolio_risk_summary(points))
    |> assign(:portfolio_risk_chart_option, option)
    |> push_event("chart:update", %{id: "portfolio-risk-chart", option: option})
  end

  defp portfolio_value_summary(points) do
    first = List.first(points)
    current = List.last(points)
    delta = Decimal.sub(current.value, first.value)

    [
      %{id: "current", label: "Current", value: current.tooltip_value},
      %{
        id: "change",
        label: "Change",
        value: format_signed_usd(delta),
        tone: decimal_delta_tone(delta)
      },
      %{id: "source", label: "Source", value: "Portfolio snapshots"}
    ]
  end

  defp portfolio_value_interpretation(points) do
    delta =
      points
      |> value_delta()
      |> Money.decimal()

    case Decimal.compare(delta, Decimal.new(0)) do
      :gt -> %{label: "Collateral value building", tone: :positive}
      :lt -> %{label: "Collateral value under pressure", tone: :negative}
      :eq -> %{label: "Collateral value stable", tone: :neutral}
    end
  end

  defp portfolio_risk_summary(points) do
    first = List.first(points)
    current = List.last(points)
    delta = current.value - first.value

    [
      %{id: "current", label: "Current", value: current.tooltip_value},
      %{
        id: "change",
        label: "Change",
        value: format_signed_points(delta),
        tone: risk_delta_tone(delta)
      },
      %{id: "source", label: "Source", value: "Portfolio snapshots"}
    ]
  end

  defp portfolio_risk_interpretation(points) do
    case risk_delta(points) do
      delta when delta > 0 -> %{label: "Risk drift increasing", tone: :warning}
      delta when delta < 0 -> %{label: "Risk easing", tone: :positive}
      _delta -> %{label: "Risk score stable", tone: :neutral}
    end
  end

  defp event_volume_summary(buckets, window) do
    total_count = event_volume_count(buckets)

    [
      %{id: "total", label: "Events", value: Integer.to_string(total_count)},
      %{id: "window", label: "Window", value: window.event_window_label},
      %{id: "source", label: "Source", value: "Activity store"}
    ]
  end

  defp event_volume_empty?(buckets), do: event_volume_count(buckets) == 0

  defp event_volume_interpretation(buckets) do
    totals = event_source_totals(buckets)

    case {Map.get(totals, "scenario", 0), Map.get(totals, "operator", 0),
          event_volume_count(buckets)} do
      {_scenario, _operator, 0} ->
        %{label: "No recent activity", tone: :neutral}

      {scenario, _operator, _total} when scenario > 0 ->
        %{label: "Scenario events active", tone: :warning}

      {_scenario, operator, _total} when operator > 0 ->
        %{label: "Operator activity present", tone: :positive}

      _activity ->
        %{label: "System activity normal", tone: :info}
    end
  end

  defp event_volume_count(buckets) do
    buckets
    |> Enum.flat_map(&Map.values(&1.sources))
    |> Enum.sum()
  end

  defp event_source_totals(buckets) do
    Enum.reduce(buckets, %{}, fn bucket, totals ->
      Map.merge(totals, bucket.sources, fn _source, left, right -> left + right end)
    end)
  end

  defp risk_pressure_summary(buckets) do
    at_risk_buckets = Enum.filter(buckets, &(&1.value in ["Elevated", "Critical"]))
    at_risk_value = at_risk_buckets |> Enum.map(& &1.collateral_value_usd) |> Money.sum()
    at_risk_count = at_risk_buckets |> Enum.map(& &1.count) |> Enum.sum()

    [
      %{id: "at-risk", label: "At-risk", value: Money.format_usd(at_risk_value), tone: :warning},
      %{id: "positions", label: "Positions", value: Integer.to_string(at_risk_count)},
      %{id: "source", label: "Source", value: "Scenario overlay"}
    ]
  end

  defp risk_pressure_interpretation(buckets) do
    risk_counts =
      Map.new(buckets, fn bucket ->
        {bucket.value, bucket.count}
      end)

    case {Map.get(risk_counts, "Critical", 0), Map.get(risk_counts, "Elevated", 0)} do
      {critical, _elevated} when critical > 0 ->
        %{label: "Critical collateral present", tone: :negative}

      {_critical, elevated} when elevated > 0 ->
        %{label: "Elevated collateral concentrated", tone: :warning}

      _risk ->
        %{label: "Pressure contained", tone: :positive}
    end
  end

  defp value_delta(points) do
    first = List.first(points)
    current = List.last(points)

    Decimal.sub(current.value, first.value)
  end

  defp risk_delta(points) do
    first = List.first(points)
    current = List.last(points)

    current.value - first.value
  end

  defp format_signed_usd(value) do
    case Decimal.compare(Money.decimal(value), Decimal.new(0)) do
      :gt -> "+#{Money.format_usd(value)}"
      :lt -> "-#{value |> Decimal.mult(Decimal.new(-1)) |> Money.format_usd()}"
      :eq -> "$0"
    end
  end

  defp format_signed_points(value) when value > 0, do: "+#{value} pts"
  defp format_signed_points(value) when value < 0, do: "#{value} pts"
  defp format_signed_points(_value), do: "0 pts"

  defp risk_delta_tone(value) when value > 0, do: :negative
  defp risk_delta_tone(value) when value < 0, do: :positive
  defp risk_delta_tone(_value), do: :neutral

  defp decimal_delta_tone(value) do
    case Decimal.compare(Money.decimal(value), Decimal.new(0)) do
      :gt -> :positive
      :lt -> :negative
      :eq -> :neutral
    end
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
    |> assign_portfolio_value_chart()
    |> assign_portfolio_risk_chart()
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
