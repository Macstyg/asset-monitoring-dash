defmodule AssetMonitoringDashWeb.DashboardLive.Components.EventFeedTest do
  use AssetMonitoringDashWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias AssetMonitoringDashWeb.DashboardLive.Components.EventFeed

  test "renders feed controls, filters, and streamed event rows" do
    document =
      render_component(&EventFeed.render/1,
        active_event_filter_chips: [source_chip()],
        event_count: 1,
        event_filter_form: event_filter_form(%{sources: ["scenario"], source_option_query: ""}),
        event_filters: %{sources: ["scenario"], source_option_query: ""},
        event_source_filter_options: [
          %{value: "scenario", label: "Scenario", icon_text: "Sc", tone: :warning},
          %{value: "operator", label: "Operator", icon_text: "O", tone: :success}
        ],
        feed_paused: false,
        rows: [{"event-row-event-001", event()}]
      )
      |> LazyHTML.from_fragment()

    assert document |> LazyHTML.query("#event-feed") |> Enum.any?()
    assert document |> LazyHTML.query("#event-count") |> LazyHTML.text() =~ "1 events"
    assert document |> LazyHTML.query("#event-feed-state") |> LazyHTML.text() =~ "streaming"

    assert document
           |> LazyHTML.query("#push-demo-event[phx-click=\"push_demo_event\"]")
           |> Enum.any?()

    assert document
           |> LazyHTML.query("#toggle-event-feed[phx-click=\"toggle_event_feed\"]")
           |> Enum.any?()

    assert document |> LazyHTML.query("#event-filters") |> Enum.any?()
    assert document |> LazyHTML.query("#active-filter-event-sources-scenario") |> Enum.any?()
    assert document |> LazyHTML.query("#event-list[phx-update=\"stream\"]") |> Enum.any?()

    assert document |> LazyHTML.query("#event-row-event-001") |> LazyHTML.text() =~
             "Price shock applied"
  end

  test "renders paused feed state" do
    document =
      render_component(&EventFeed.render/1,
        active_event_filter_chips: [],
        event_count: 0,
        event_filter_form: event_filter_form(%{sources: [], source_option_query: ""}),
        event_filters: %{sources: [], source_option_query: ""},
        event_source_filter_options: [],
        feed_paused: true,
        rows: []
      )
      |> LazyHTML.from_fragment()

    assert document |> LazyHTML.query("#event-feed-state") |> LazyHTML.text() =~ "paused"
    assert document |> LazyHTML.query("#event-list-empty") |> LazyHTML.text() =~ "No events"
  end

  defp event_filter_form(filters) do
    Phoenix.Component.to_form(
      %{
        "sources" => filters.sources,
        "source_option_query" => filters.source_option_query
      },
      as: :event_filters
    )
  end

  defp source_chip do
    %{
      id: "event-sources-scenario",
      field: "event_sources",
      value: "scenario",
      group: "Source",
      label: "Scenario",
      icon_text: "Sc",
      tone: :warning
    }
  end

  defp event do
    %{
      actor: "Scenario engine",
      chain: "Polygon",
      detail: "Aegis Dragon Helm repriced lower.",
      severity_label: "Critical",
      severity_tone: :danger,
      source_label: "Scenario",
      source_tone: :warning,
      status: "risk",
      time_label: "now",
      title: "Price shock applied",
      tone: :danger
    }
  end
end
