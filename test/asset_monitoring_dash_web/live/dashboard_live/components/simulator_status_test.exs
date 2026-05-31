defmodule AssetMonitoringDashWeb.DashboardLive.Components.SimulatorStatusTest do
  use AssetMonitoringDashWeb.ComponentCase, async: true

  alias AssetMonitoringDashWeb.DashboardLive.Components.SimulatorStatus

  test "renders running simulator state and controls" do
    document =
      render_component(&SimulatorStatus.render/1,
        scenario_count: 2,
        status: %{
          interval_ms: 4_000,
          max_active_scenarios: 5,
          next_event_index: 7,
          paused?: false,
          running?: true,
          scenario_every: 4,
          tick_index: 6
        }
      )
      |> LazyHTML.from_fragment()

    assert document |> LazyHTML.query("#simulator-status") |> Enum.any?()
    assert document |> LazyHTML.query("#simulator-state") |> LazyHTML.text() =~ "Streaming"
    assert document |> LazyHTML.query("#simulator-tick-index") |> LazyHTML.text() =~ "6"
    assert document |> LazyHTML.query("#simulator-next-event-index") |> LazyHTML.text() =~ "7"

    assert document |> LazyHTML.query("#simulator-scenario-cadence") |> LazyHTML.text() =~
             "every 4 ticks"

    assert document |> LazyHTML.query("#simulator-active-scenarios") |> LazyHTML.text() =~ "2 / 5"

    assert document |> LazyHTML.query("#simulator-runtime-path") |> LazyHTML.text() =~
             "Supervised GenServer"

    assert document |> LazyHTML.query("#simulator-runtime-path") |> LazyHTML.text() =~
             "Scenarios, events, audit log"

    assert document |> LazyHTML.query("#simulator-runtime-path") |> LazyHTML.text() =~
             "Dashboard and detail refresh"

    assert document
           |> LazyHTML.query("#simulator-run-tick[phx-click=\"push_demo_event\"]")
           |> Enum.any?()

    assert document
           |> LazyHTML.query("#simulator-toggle[phx-click=\"toggle_event_feed\"]")
           |> Enum.any?()

    assert document
           |> LazyHTML.query("#simulator-reset-runtime[phx-click=\"reset_demo_runtime\"]")
           |> Enum.any?()

    assert document |> LazyHTML.query("#simulator-toggle") |> LazyHTML.text() =~ "Pause process"
  end

  test "renders offline state with disabled controls" do
    document =
      render_component(&SimulatorStatus.render/1,
        scenario_count: 0,
        status: %{
          interval_ms: nil,
          max_active_scenarios: 0,
          next_event_index: 0,
          paused?: false,
          running?: false,
          scenario_every: nil,
          tick_index: 0
        }
      )
      |> LazyHTML.from_fragment()

    assert document |> LazyHTML.query("#simulator-state") |> LazyHTML.text() =~ "Offline"

    assert document |> LazyHTML.query("#simulator-scenario-cadence") |> LazyHTML.text() =~
             "manual"

    assert document |> LazyHTML.query("#simulator-run-tick[disabled]") |> Enum.any?()
    assert document |> LazyHTML.query("#simulator-toggle[disabled]") |> Enum.any?()
  end
end
