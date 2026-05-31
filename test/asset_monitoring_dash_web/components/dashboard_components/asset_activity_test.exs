defmodule AssetMonitoringDashWeb.DashboardComponents.AssetActivityTest do
  use AssetMonitoringDashWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias AssetMonitoringDashWeb.DashboardComponents.AssetActivity

  test "renders event filters, rows, chips, and focused state" do
    filters = %{sources: ["scenario"], source_option_query: ""}

    chip = %{
      id: "asset-event-sources-scenario",
      field: "asset_event_sources",
      value: "scenario",
      group: "Source",
      label: "Scenario",
      icon_text: "Sc",
      tone: :warning
    }

    event = %{
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

    document =
      render_component(&AssetActivity.render/1,
        active_filter_chips: [chip],
        event_count: 1,
        event_filter_form: event_filter_form(filters),
        event_filters: filters,
        rows: [{"asset-event-row-event-shock-asset-001", event}],
        source_filter_options: [
          %{value: "scenario", label: "Scenario", icon_text: "Sc", tone: :warning},
          %{value: "operator", label: "Operator", icon_text: "O", tone: :success}
        ]
      )
      |> LazyHTML.from_fragment()

    assert document |> LazyHTML.query("#asset-activity") |> Enum.any?()
    assert document |> LazyHTML.query("#asset-activity-filters") |> Enum.any?()

    assert document
           |> LazyHTML.query("#active-filter-asset-event-sources-scenario")
           |> Enum.any?()

    assert document |> LazyHTML.query("#asset-event-row-event-shock-asset-001") |> Enum.any?()
  end

  test "renders an empty state title for an unfiltered asset" do
    filters = %{sources: [], source_option_query: ""}

    document =
      render_component(&AssetActivity.render/1,
        active_filter_chips: [],
        event_count: 0,
        event_filter_form: event_filter_form(filters),
        event_filters: filters,
        rows: [],
        source_filter_options: []
      )
      |> LazyHTML.from_fragment()

    assert document
           |> LazyHTML.query("#asset-event-list-empty")
           |> LazyHTML.text() =~ "No recorded activity"
  end

  defp event_filter_form(filters) do
    Phoenix.Component.to_form(
      %{
        "sources" => filters.sources,
        "source_option_query" => filters.source_option_query
      },
      as: :asset_event_filters
    )
  end
end
