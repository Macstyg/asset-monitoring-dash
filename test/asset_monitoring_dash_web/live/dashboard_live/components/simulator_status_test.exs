defmodule AssetMonitoringDashWeb.DashboardLive.Components.SimulatorStatusTest do
  use AssetMonitoringDashWeb.ComponentCase, async: true

  alias AssetMonitoringDashWeb.DashboardLive.Components.SimulatorStatus

  test "renders running simulator state and controls" do
    document =
      render_component(&SimulatorStatus.render/1,
        last_action: %{
          context: "Arbitrum",
          detail: "Ancient Mech Core · Forces price-feed freshness outside the trusted window.",
          label: "Scenario tick",
          timestamp: "18:42:10 UTC",
          title: "Oracle stale",
          tone: :danger
        },
        scenario_count: 2,
        scenario_summary: [
          %{
            id: "price_shock",
            label: "Price shock",
            description: "Reprices collateral lower and raises LTV pressure.",
            count: 1
          },
          %{
            id: "oracle_stale",
            label: "Oracle stale",
            description: "Forces price-feed freshness outside the trusted window.",
            count: 1
          }
        ],
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

    assert document |> LazyHTML.query("#simulator-scenario-summary") |> LazyHTML.text() =~
             "Active scenario mix"

    assert document |> LazyHTML.query("#simulator-scenario-count-price_shock") |> LazyHTML.text() =~
             "1"

    assert document |> LazyHTML.query("#simulator-scenario-count-price_shock") |> LazyHTML.text() =~
             "Price shock"

    assert document |> LazyHTML.query("#simulator-scenario-count-oracle_stale") |> LazyHTML.text() =~
             "Oracle stale"

    assert document |> LazyHTML.query("#simulator-runtime-path") |> LazyHTML.text() =~
             "Supervised GenServer"

    assert document |> LazyHTML.query("#simulator-runtime-path") |> LazyHTML.text() =~
             "Scenarios, events, audit log"

    assert document |> LazyHTML.query("#simulator-runtime-path") |> LazyHTML.text() =~
             "Dashboard and detail refresh"

    assert document |> LazyHTML.query("#simulator-last-action") |> LazyHTML.text() =~
             "Last simulator action"

    assert document |> LazyHTML.query("#simulator-last-action") |> LazyHTML.text() =~
             "Oracle stale"

    assert document |> LazyHTML.query("#simulator-last-action-kind") |> LazyHTML.text() =~
             "Scenario tick"

    assert document |> LazyHTML.query("#simulator-last-action-detail") |> LazyHTML.text() =~
             "Ancient Mech Core"

    assert document |> LazyHTML.query("#simulator-last-action-time") |> LazyHTML.text() =~
             "18:42:10 UTC"

    assert document
           |> LazyHTML.query("#simulator-run-event-tick[phx-click=\"run_event_tick\"]")
           |> Enum.any?()

    assert document
           |> LazyHTML.query("#simulator-run-scenario-tick[phx-click=\"run_scenario_tick\"]")
           |> Enum.any?()

    assert document
           |> LazyHTML.query("#simulator-toggle[phx-click=\"toggle_simulator_process\"]")
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

    assert document |> LazyHTML.query("#simulator-last-action") |> LazyHTML.text() =~
             "Waiting for the next tick"

    assert document |> LazyHTML.query("#simulator-last-action-kind") |> Enum.empty?()
    assert document |> LazyHTML.query("#simulator-run-event-tick[disabled]") |> Enum.any?()
    assert document |> LazyHTML.query("#simulator-run-scenario-tick[disabled]") |> Enum.any?()
    assert document |> LazyHTML.query("#simulator-toggle[disabled]") |> Enum.any?()
  end

  test "disables scenario ticks when the scenario cap is reached" do
    document =
      render_component(&SimulatorStatus.render/1,
        scenario_count: 5,
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

    assert document |> LazyHTML.query("#simulator-run-event-tick:not([disabled])") |> Enum.any?()

    assert document
           |> LazyHTML.query("#simulator-run-scenario-tick[disabled]")
           |> Enum.any?()

    assert document
           |> LazyHTML.query("#simulator-run-scenario-tick")
           |> LazyHTML.attribute("title")
           |> List.first() =~ "Scenario cap reached"
  end
end
