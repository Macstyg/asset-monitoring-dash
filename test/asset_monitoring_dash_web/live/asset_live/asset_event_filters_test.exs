defmodule AssetMonitoringDashWeb.AssetLive.AssetEventFiltersTest do
  use AssetMonitoringDashWeb.ConnCase, async: true

  alias AssetMonitoringDashWeb.AssetLive.AssetEventFilters

  test "normalizes activity source filters from params" do
    filters =
      AssetEventFilters.normalize(%{
        "sources" => ["scenario"],
        "source_option_query" => "sc"
      })

    assert filters.sources == ["scenario"]
    assert filters.source_option_query == "sc"
  end

  test "builds active source chips" do
    chips = AssetEventFilters.active_chips(%{sources: ["operator"], source_option_query: ""})

    assert [
             %{
               id: "asset-event-sources-operator",
               field: "asset_event_sources",
               value: "operator",
               group: "Source",
               label: "Operator",
               icon_text: "O",
               tone: :success
             }
           ] = chips
  end

  test "filters events by explicit or derived source" do
    events = [
      %{id: "scenario-event", kind: :scenario},
      %{id: "operator-event", source_value: "operator"},
      %{id: "system-event"}
    ]

    assert AssetEventFilters.filter_events(events, []) == events

    assert [%{id: "scenario-event"}] =
             AssetEventFilters.filter_events(events, ["scenario"])

    assert [%{id: "operator-event"}] =
             AssetEventFilters.filter_events(events, ["operator"])
  end
end
