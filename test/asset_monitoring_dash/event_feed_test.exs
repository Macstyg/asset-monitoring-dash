defmodule AssetMonitoringDash.EventFeedTest do
  use ExUnit.Case, async: true

  alias AssetMonitoringDash.EventFeed

  test "starts with deterministic feed events" do
    events = EventFeed.initial_events()

    assert length(events) == 5

    assert Enum.map(events, & &1.id) == [
             "event-001",
             "event-002",
             "event-003",
             "event-004",
             "event-005"
           ]
  end

  test "pushes a generated event to the top of the feed" do
    feed = EventFeed.push_demo_event(EventFeed.initial_events(), 0)

    assert feed.next_event_index == 1
    assert [%{id: "event-live-1", time_label: "now"} | _events] = feed.visible_events
    assert length(feed.visible_events) == 6
  end

  test "keeps generated event labels relative and bounds visible history" do
    feed =
      0..2
      |> Enum.reduce(
        %{visible_events: EventFeed.initial_events(), next_event_index: 0},
        fn _push, feed ->
          EventFeed.push_demo_event(feed.visible_events, feed.next_event_index)
        end
      )

    assert length(feed.visible_events) == 6

    assert Enum.map(feed.visible_events, & &1.id) == [
             "event-live-3",
             "event-live-2",
             "event-live-1",
             "event-001",
             "event-002",
             "event-003"
           ]

    assert Enum.map(feed.visible_events, & &1.time_label) == [
             "now",
             "4s ago",
             "8s ago",
             "14:28:09",
             "14:27:31",
             "14:26:44"
           ]
  end
end
