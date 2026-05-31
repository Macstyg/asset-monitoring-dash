defmodule AssetMonitoringDashWeb.SharedComponents.EventItemTest do
  use AssetMonitoringDashWeb.ComponentCase, async: true

  alias AssetMonitoringDashWeb.SharedComponents.EventItem

  test "renders an operational event row" do
    document =
      render_component(&EventItem.render/1,
        id: "event-row-event-001",
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
      )
      |> LazyHTML.from_fragment()

    assert document |> LazyHTML.query("#event-row-event-001") |> Enum.any?()
    assert LazyHTML.text(document) =~ "now"
    assert LazyHTML.text(document) =~ "Price shock applied"
    assert LazyHTML.text(document) =~ "Polygon"
    assert LazyHTML.text(document) =~ "Aegis Dragon Helm repriced lower."
    assert LazyHTML.text(document) =~ "Scenario"
    assert LazyHTML.text(document) =~ "Critical"
    assert LazyHTML.text(document) =~ "by Scenario engine"
    assert LazyHTML.text(document) =~ "risk"
  end
end
