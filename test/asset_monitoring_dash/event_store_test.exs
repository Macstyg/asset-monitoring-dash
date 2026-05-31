defmodule AssetMonitoringDash.EventStoreTest do
  use AssetMonitoringDash.DataCase, async: false

  alias AssetMonitoringDash.EventStore

  test "publishes generated scenario events above seeded dashboard events" do
    expected_asset_id = asset_id("asset-001")

    asset = %{
      id: expected_asset_id,
      dom_id: "asset-001",
      name: "Aegis Dragon Helm",
      chain: "Polygon",
      ltv_percent: 67.8
    }

    events = EventStore.push_price_shock_event(asset, 12)

    assert [
             %{id: "event-shock-asset-001", asset_id: ^expected_asset_id, kind: :scenario}
             | _events
           ] =
             events

    assert length(events) == 6

    assert [
             %{id: "event-shock-asset-001", asset_id: ^expected_asset_id, kind: :scenario},
             %{id: "event-001", kind: :system} | _events
           ] =
             EventStore.visible_events()
  end

  test "resets generated event history" do
    asset = %{
      id: asset_id("asset-001"),
      dom_id: "asset-001",
      name: "Aegis Dragon Helm",
      chain: "Polygon",
      ltv_percent: 67.8
    }

    EventStore.push_price_shock_event(asset, 12)
    EventStore.reset_mutable_events()

    assert Enum.map(EventStore.visible_events(), & &1.id) == [
             "event-001",
             "event-002",
             "event-003",
             "event-004",
             "event-005"
           ]
  end

  test "publishes generated events for one asset inspection history" do
    asset = %{
      id: asset_id("asset-001"),
      dom_id: "asset-001",
      name: "Aegis Dragon Helm",
      chain: "Polygon",
      ltv_percent: 67.8
    }

    other_asset = %{
      id: asset_id("asset-002"),
      dom_id: "asset-002",
      name: "Citadel Founder Parcel",
      chain: "Ethereum",
      ltv_percent: 75.2
    }

    EventStore.push_price_shock_event(other_asset, 12)
    EventStore.push_price_shock_event(asset, 12)

    expected_asset_id = asset_id("asset-001")

    assert [%{id: "event-shock-asset-001", asset_id: ^expected_asset_id}] =
             EventStore.visible_events_for_asset("asset-001")
  end

  defp asset_id(code), do: AssetMonitoringDash.Assets.resolve_persisted_asset_id(code)
end
