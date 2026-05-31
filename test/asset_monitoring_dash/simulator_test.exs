defmodule AssetMonitoringDash.SimulatorTest do
  use AssetMonitoringDash.DataCase, async: false

  alias AssetMonitoringDash.ActivityLog
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

  test "reports and changes runtime status" do
    name = :"simulator-#{System.unique_integer([:positive])}"

    start_supervised!(
      {Simulator, enabled: true, interval_ms: :manual, name: name, next_event_index: 3}
    )

    assert %{paused?: false, next_event_index: 3, interval_ms: :manual} = Simulator.status(name)
    assert %{paused?: true, next_event_index: 3} = Simulator.pause(name)
    assert %{paused?: false, next_event_index: 3} = Simulator.resume(name)
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
