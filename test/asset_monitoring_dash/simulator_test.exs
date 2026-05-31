defmodule AssetMonitoringDash.SimulatorTest do
  use AssetMonitoringDash.DataCase, async: false

  alias AssetMonitoringDash.ActivityLog
  alias AssetMonitoringDash.AssetScenarioStore
  alias AssetMonitoringDash.ReviewState
  alias AssetMonitoringDash.ReviewStore
  alias AssetMonitoringDash.Simulator

  test "can be disabled by configuration options" do
    assert :ignore = Simulator.start_link(enabled: false)
  end

  test "manual ticks persist a demo event and broadcast the updated feed" do
    name = :"simulator-#{System.unique_integer([:positive])}"

    start_supervised!(
      {Simulator, enabled: true, interval_ms: :manual, name: name, next_event_index: 0}
    )

    Simulator.subscribe()

    assert %{next_event_index: 1, event_history: [%{id: "event-live-1"} | _]} =
             Simulator.tick(name)

    assert_receive {Simulator, :event_recorded,
                    %{next_event_index: 1, event_history: [%{id: "event-live-1"} | _]}}

    assert [%{id: "event-live-1"} | _events] = ActivityLog.visible_events()
  end

  test "starts from the persisted demo event cursor" do
    name = :"simulator-#{System.unique_integer([:positive])}"

    ActivityLog.record_demo_event(0)

    start_supervised!({Simulator, enabled: true, interval_ms: :manual, name: name})

    assert %{next_event_index: 2, event_history: [%{id: "event-live-2"} | _]} =
             Simulator.tick(name)
  end

  test "manual event ticks use the explicit event tick API" do
    name = :"simulator-#{System.unique_integer([:positive])}"

    start_supervised!(
      {Simulator, enabled: true, interval_ms: :manual, name: name, next_event_index: 0}
    )

    Simulator.subscribe()

    assert %{next_event_index: 1, event_history: [%{id: "event-live-1"} | _]} =
             Simulator.event_tick(name)

    assert_receive {Simulator, :event_recorded,
                    %{next_event_index: 1, event_history: [%{id: "event-live-1"} | _]}}
  end

  test "manual scenario ticks apply the next scenario without waiting for cadence" do
    name = :"simulator-#{System.unique_integer([:positive])}"

    start_supervised!(
      {Simulator,
       enabled: true,
       interval_ms: :manual,
       max_active_scenarios: 5,
       name: name,
       scenario_every: 4,
       tick_index: 1}
    )

    Simulator.subscribe()

    assert %{
             asset: %{oracle_status: "Stale"},
             event_history: [
               %{id: "event-oracle_stale-" <> _asset_key, kind: :scenario}
               | _events
             ],
             next_event_index: 0,
             scenario_id: "oracle_stale"
           } = Simulator.scenario_tick(name)

    assert_receive {Simulator, :scenario_applied, %{scenario_id: "oracle_stale"}}
  end

  test "reports and changes runtime status" do
    name = :"simulator-#{System.unique_integer([:positive])}"

    start_supervised!(
      {Simulator, enabled: true, interval_ms: :manual, name: name, next_event_index: 3}
    )

    assert %{paused?: false, next_event_index: 3, interval_ms: :manual} = Simulator.status(name)
    assert %{paused?: true, next_event_index: 3} = Simulator.pause(name)
    assert %{paused?: false, next_event_index: 3} = Simulator.resume(name)
  end

  test "scheduled ticks can apply a persisted scenario and broadcast dashboard refresh state" do
    name = :"simulator-#{System.unique_integer([:positive])}"
    reviewed_asset = AssetMonitoringDash.Assets.get_persisted_asset("asset-001")

    ReviewStore.mark_reviewed(reviewed_asset.id)

    pid =
      start_supervised!(
        {Simulator,
         enabled: true,
         interval_ms: :manual,
         max_active_scenarios: 5,
         name: name,
         scenario_every: 1,
         tick_index: 0}
      )

    Simulator.subscribe()
    send(pid, :tick)

    assert_receive {Simulator, :scenario_applied,
                    %{
                      asset: %{id: asset_id},
                      event_history: [
                        %{id: "event-review-unreviewed-" <> _review_asset_key, kind: :operator},
                        %{id: "event-shock-" <> _shock_asset_key, kind: :scenario}
                        | _events
                      ],
                      next_event_index: 0,
                      review_states: review_states,
                      scenario_id: "price_shock",
                      shocked_asset_ids: shocked_asset_ids
                    }}

    assert AssetMonitoringDash.Assets.asset_id_in_set?(asset_id, shocked_asset_ids)
    assert AssetScenarioStore.shocked_asset_ids() == shocked_asset_ids
    assert ReviewState.state_for(asset_id, review_states).id == :unreviewed
    assert ReviewStore.current_state(asset_id).id == :unreviewed
  end

  test "scheduled scenario ticks rotate through scenario types" do
    name = :"simulator-#{System.unique_integer([:positive])}"

    pid =
      start_supervised!(
        {Simulator,
         enabled: true,
         interval_ms: :manual,
         max_active_scenarios: 5,
         name: name,
         scenario_every: 1,
         tick_index: 1}
      )

    Simulator.subscribe()
    send(pid, :tick)

    assert_receive {Simulator, :scenario_applied,
                    %{
                      asset: %{oracle_status: "Stale"},
                      event_history: [
                        %{id: "event-oracle_stale-" <> _asset_key, title: "Oracle stale"}
                        | _events
                      ],
                      scenario_id: "oracle_stale"
                    }}
  end

  test "scheduled ticks fall back to activity events after scenario cap is reached" do
    name = :"simulator-#{System.unique_integer([:positive])}"

    pid =
      start_supervised!(
        {Simulator,
         enabled: true,
         interval_ms: :manual,
         max_active_scenarios: 0,
         name: name,
         scenario_every: 1,
         tick_index: 0}
      )

    Simulator.subscribe()
    send(pid, :tick)

    assert_receive {Simulator, :event_recorded,
                    %{next_event_index: 1, event_history: [%{id: "event-live-1"} | _]}}
  end

  test "ignores scheduled ticks while paused" do
    name = :"simulator-#{System.unique_integer([:positive])}"

    pid =
      start_supervised!(
        {Simulator, enabled: true, interval_ms: :manual, name: name, next_event_index: 0}
      )

    Simulator.pause(name)
    send(pid, :tick)
    _state = :sys.get_state(pid)

    refute Enum.any?(ActivityLog.visible_events(), &(&1.id == "event-live-1"))
  end
end
