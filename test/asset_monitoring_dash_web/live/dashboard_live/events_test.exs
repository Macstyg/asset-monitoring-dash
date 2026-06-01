defmodule AssetMonitoringDashWeb.DashboardLive.EventsTest do
  use AssetMonitoringDashWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import AssetMonitoringDashWeb.DashboardLiveTestHelpers
  alias AssetMonitoringDash.ActivityLog
  alias AssetMonitoringDash.ReviewState
  alias AssetMonitoringDash.Simulator

  test "shows simulator status and controls the supervised process", %{conn: conn} do
    start_supervised!(
      {Simulator,
       enabled: true,
       interval_ms: :manual,
       max_active_scenarios: 5,
       name: Simulator,
       next_event_index: 0,
       scenario_every: 4,
       tick_index: 0}
    )

    {:ok, view, _html} = live(conn, ~p"/")

    initial_option = chart_option_from_render(view)
    flush_chart_updates(view)

    assert has_element?(view, "#simulator-state", "Streaming")
    assert has_element?(view, "#simulator-tick-index", "0")
    assert has_element?(view, "#simulator-next-event-index", "0")
    assert has_element?(view, "#simulator-scenario-cadence", "every 4 ticks")
    assert has_element?(view, "#simulator-active-scenarios", "0 / 5")

    view
    |> element("#simulator-run-event-tick")
    |> render_click()

    assert has_element?(view, "#event-row-event-live-1")
    assert has_element?(view, "#simulator-tick-index", "1")
    assert has_element?(view, "#simulator-next-event-index", "1")
    assert has_element?(view, "#simulator-last-action-kind", "Event tick")
    assert has_element?(view, "#simulator-last-action", "Oracle heartbeat")

    event_option =
      assert_chart_update(
        view,
        &(latest_chart_value(&1, "System") > 0 and &1 != initial_option)
      )

    assert latest_chart_value(event_option, "System") > 0

    view
    |> element("#simulator-run-scenario-tick")
    |> render_click()

    assert has_element?(view, "#simulator-tick-index", "2")
    assert has_element?(view, "#simulator-next-event-index", "1")
    assert has_element?(view, "#simulator-active-scenarios", "1 / 5")
    assert has_element?(view, "#simulator-scenario-count-oracle_stale", "Oracle stale")
    assert has_element?(view, "#simulator-last-action-kind", "Scenario tick")
    assert has_element?(view, "#simulator-last-action", "Oracle stale")
    scenario_option = assert_chart_update(view, &(latest_chart_value(&1, "Scenario") == 1))
    assert latest_chart_value(scenario_option, "Scenario") == 1

    pressure_option =
      assert_chart_update(
        view,
        "risk-pressure-chart",
        &(chart_key(List.first(&1.series), :type) == "pie")
      )

    assert chart_values(pressure_option, "Collateral") |> Enum.sum() > 3_000_000

    view
    |> element("#simulator-toggle")
    |> render_click()

    assert has_element?(view, "#simulator-state", "Paused")
    assert has_element?(view, "#event-feed-state", "paused")

    view
    |> element("#simulator-toggle")
    |> render_click()

    assert has_element?(view, "#simulator-state", "Streaming")
    assert has_element?(view, "#event-feed-state", "streaming")
  end

  test "scenario tick button is disabled when scenario cap prevents chart updates", %{conn: conn} do
    start_supervised!(
      {Simulator,
       enabled: true,
       interval_ms: :manual,
       max_active_scenarios: 0,
       name: Simulator,
       next_event_index: 0,
       scenario_every: 4,
       tick_index: 0}
    )

    {:ok, view, _html} = live(conn, ~p"/")
    flush_chart_updates(view)

    assert has_element?(view, "#simulator-run-scenario-tick[disabled]")
    assert has_element?(view, ~s(#simulator-run-scenario-tick[title*="Scenario cap reached"]))
    refute has_element?(view, "#event-row-event-live-1")
    refute_push_event(view, "chart:update", %{id: "event-volume-chart", option: _option})
  end

  test "filters event feed by source kind", %{conn: conn} do
    asset = asset_fixture("asset-001")

    ActivityLog.record_price_shock(%{asset | ltv_percent: 67.8}, 12)
    ActivityLog.record_review(asset, ReviewState.state(:reviewed))

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#event-count", "6 events")
    assert has_element?(view, "#event-row-event-review-reviewed-asset-001")
    assert has_element?(view, "#event-row-event-shock-asset-001")

    view
    |> form("#event-filters", %{
      "event_filters" => %{"sources" => ["scenario"], "source_option_query" => ""}
    })
    |> render_change()

    assert has_element?(view, "#event-count", "1 events")
    assert has_element?(view, "#active-event-filter-chips")
    assert has_element?(view, "#active-filter-event-sources-scenario", "Scenario")
    assert has_element?(view, "#event-row-event-shock-asset-001", "Price shock applied")
    refute has_element?(view, "#event-row-event-review-reviewed-asset-001")
    refute has_element?(view, "#event-row-event-001")

    view
    |> form("#event-filters", %{
      "event_filters" => %{"sources" => ["operator"], "source_option_query" => ""}
    })
    |> render_change()

    assert has_element?(view, "#event-count", "1 events")
    assert has_element?(view, "#event-row-event-review-reviewed-asset-001", "Position reviewed")
    refute has_element?(view, "#event-row-event-shock-asset-001")

    view
    |> form("#event-filters", %{
      "event_filters" => %{"sources" => ["system"], "source_option_query" => ""}
    })
    |> render_change()

    assert has_element?(view, "#event-count", "4 events")
    assert has_element?(view, "#event-row-event-001")
    refute has_element?(view, "#event-row-event-review-reviewed-asset-001")
    refute has_element?(view, "#event-row-event-shock-asset-001")

    view
    |> form("#event-filters", %{
      "event_filters" => %{"sources" => [""], "source_option_query" => ""}
    })
    |> render_change()

    assert has_element?(view, "#event-count", "6 events")
    assert has_element?(view, "#event-row-event-review-reviewed-asset-001")
    assert has_element?(view, "#event-row-event-shock-asset-001")
  end

  test "combines multiple event source filters", %{conn: conn} do
    asset = asset_fixture("asset-001")

    ActivityLog.record_price_shock(%{asset | ltv_percent: 67.8}, 12)
    ActivityLog.record_review(asset, ReviewState.state(:reviewed))

    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#event-filters", %{
      "event_filters" => %{"sources" => ["scenario", "operator"], "source_option_query" => ""}
    })
    |> render_change()

    assert has_element?(view, "#event-count", "2 events")
    assert has_element?(view, "#event-row-event-shock-asset-001")
    assert has_element?(view, "#event-row-event-review-reviewed-asset-001")
    assert has_element?(view, "#active-filter-event-sources-scenario")
    assert has_element?(view, "#active-filter-event-sources-operator")
    refute has_element?(view, "#event-row-event-001")

    view
    |> element("#active-filter-event-sources-scenario")
    |> render_click()

    assert has_element?(view, "#event-count", "1 events")
    assert has_element?(view, "#event-row-event-review-reviewed-asset-001")
    refute has_element?(view, "#event-row-event-shock-asset-001")
    refute has_element?(view, "#active-filter-event-sources-scenario")
  end

  test "event source filters can show an empty feed slice", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#event-filters", %{
      "event_filters" => %{"sources" => ["scenario"], "source_option_query" => ""}
    })
    |> render_change()

    assert has_element?(view, "#event-count", "0 events")
    assert has_element?(view, "#event-list-empty", "No events for this filter.")
    refute has_element?(view, "#event-row-event-001")
  end

  test "active event source filters are not displaced by hidden system ticks", %{conn: conn} do
    start_manual_simulator!()

    asset = asset_fixture("asset-001")

    ActivityLog.record_price_shock(%{asset | ltv_percent: 67.8}, 12)

    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#event-filters", %{
      "event_filters" => %{"sources" => ["scenario"], "source_option_query" => ""}
    })
    |> render_change()

    assert has_element?(view, "#event-count", "1 events")
    assert has_element?(view, "#event-row-event-shock-asset-001")

    for _index <- 1..3 do
      view
      |> element("#simulator-run-event-tick")
      |> render_click()
    end

    assert has_element?(view, "#event-count", "1 events")
    assert has_element?(view, "#event-row-event-shock-asset-001")
    refute has_element?(view, "#event-row-event-live-3")
  end

  test "keeps the visible event feed bounded", %{conn: conn} do
    start_manual_simulator!()

    {:ok, view, _html} = live(conn, ~p"/")

    for _index <- 1..3 do
      view
      |> element("#simulator-run-event-tick")
      |> render_click()
    end

    assert has_element?(view, "#event-count", "6 events")
    assert has_element?(view, "#event-row-event-live-3")
    assert has_element?(view, "#event-row-event-live-3", "now")
    assert has_element?(view, "#event-row-event-live-2", "4s ago")
    assert has_element?(view, "#event-row-event-live-1", "8s ago")
    refute has_element?(view, "#event-row-event-005")
  end

  defp start_manual_simulator! do
    start_supervised!(
      {Simulator,
       enabled: true,
       interval_ms: :manual,
       max_active_scenarios: 5,
       name: Simulator,
       next_event_index: 0,
       scenario_every: 4,
       tick_index: 0}
    )
  end

  defp latest_chart_value(option, source_name) do
    option
    |> chart_values(source_name)
    |> List.last()
  end

  defp chart_values(option, source_name) do
    option.series
    |> Enum.find(&(chart_key(&1, :name) == source_name))
    |> chart_key(:data)
    |> Enum.map(&chart_point_value/1)
  end

  defp chart_point_value(%{value: value}), do: value
  defp chart_point_value(%{"value" => value}), do: value
  defp chart_point_value(value), do: value

  defp chart_option_from_render(view) do
    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query("#event-volume-chart")
    |> LazyHTML.attribute("data-chart-option")
    |> List.first()
    |> Jason.decode!()
    |> atomize_chart_keys()
  end

  defp atomize_chart_keys(value) when is_list(value), do: Enum.map(value, &atomize_chart_keys/1)

  defp atomize_chart_keys(value) when is_map(value) do
    Map.new(value, fn {key, nested_value} ->
      {String.to_existing_atom(key), atomize_chart_keys(nested_value)}
    end)
  end

  defp atomize_chart_keys(value), do: value

  defp chart_key(map, key), do: Map.get(map, key) || Map.fetch!(map, Atom.to_string(key))

  defp assert_chart_update(view, predicate),
    do: assert_chart_update(view, "event-volume-chart", predicate)

  defp assert_chart_update(view, chart_id, predicate, attempts \\ 6)

  defp assert_chart_update(_view, chart_id, _predicate, 0) do
    flunk("expected matching #{chart_id} update")
  end

  defp assert_chart_update(view, chart_id, predicate, attempts) do
    %{proxy: {ref, _topic, _}} = view

    receive do
      {^ref, {:push_event, "chart:update", %{id: ^chart_id, option: option}}} ->
        case predicate.(option) do
          true -> option
          false -> assert_chart_update(view, chart_id, predicate, attempts - 1)
        end
    after
      100 -> flunk("expected #{chart_id} update")
    end
  end

  defp flush_chart_updates(view) do
    %{proxy: {ref, _topic, _}} = view

    receive do
      {^ref, {:push_event, "chart:update", %{}}} ->
        flush_chart_updates(view)
    after
      0 -> :ok
    end
  end
end
