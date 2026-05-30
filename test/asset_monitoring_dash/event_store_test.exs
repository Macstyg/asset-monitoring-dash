defmodule AssetMonitoringDash.EventStoreTest do
  use ExUnit.Case

  alias AssetMonitoringDash.EventStore

  setup do
    EventStore.reset_all()

    :ok
  end

  test "publishes generated scenario events above seeded dashboard events" do
    asset = %{
      id: "asset-001",
      name: "Aegis Dragon Helm",
      chain: "Polygon",
      ltv_percent: 67.8
    }

    events = EventStore.push_price_shock_event(asset, 12)

    assert [%{id: "event-shock-asset-001", asset_id: "asset-001", kind: :scenario} | _events] =
             events

    assert length(events) == 6

    assert [
             %{id: "event-shock-asset-001", asset_id: "asset-001", kind: :scenario},
             %{id: "event-001", kind: :system} | _events
           ] =
             EventStore.visible_events()
  end

  test "resets generated event history" do
    asset = %{
      id: "asset-001",
      name: "Aegis Dragon Helm",
      chain: "Polygon",
      ltv_percent: 67.8
    }

    EventStore.push_price_shock_event(asset, 12)
    EventStore.reset_all()

    assert Enum.map(EventStore.visible_events(), & &1.id) == [
             "event-001",
             "event-002",
             "event-003",
             "event-004",
             "event-005"
           ]
  end
end
