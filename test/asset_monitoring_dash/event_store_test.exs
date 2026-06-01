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

  test "buckets recent persisted events by source kind" do
    asset = %{
      id: asset_id("asset-001"),
      dom_id: "asset-001",
      name: "Aegis Dragon Helm",
      chain: "Polygon",
      ltv_percent: 67.8
    }

    EventStore.push_price_shock_event(asset, 12)
    EventStore.push_demo_event(0)

    last_bucket =
      EventStore.event_source_buckets()
      |> List.last()

    assert last_bucket.label == "now"
    assert last_bucket.sources["scenario"] == 1
    assert last_bucket.sources["system"] == 1
  end

  test "formats minute-scale event bucket labels for chart axes" do
    labels =
      EventStore.event_source_buckets(12, 60)
      |> Enum.map(& &1.label)

    assert List.first(labels) == "-12m"
    assert List.last(labels) == "now"
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

  test "publishes typed scenario events" do
    expected_asset_id = asset_id("asset-001")

    asset = %{
      id: expected_asset_id,
      dom_id: "asset-001",
      name: "Aegis Dragon Helm",
      chain: "Polygon",
      current_value_usd: Decimal.new("5637.60"),
      loan_value_usd: Decimal.new("2900.00"),
      ltv_percent: Decimal.new("51.4"),
      market_depth_usd: Decimal.new("7560.00"),
      oracle_freshness_seconds: 720
    }

    assert [
             %{
               id: "event-oracle_stale-asset-001",
               asset_id: ^expected_asset_id,
               kind: :scenario,
               title: "Oracle stale"
             }
             | _events
           ] = EventStore.push_scenario_event(asset, "oracle_stale")
  end

  defp asset_id(code), do: AssetMonitoringDash.Assets.resolve_persisted_asset_id(code)
end
