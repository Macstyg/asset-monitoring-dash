defmodule AssetMonitoringDashWeb.UI.TabsTest do
  use AssetMonitoringDashWeb.ComponentCase, async: true

  alias AssetMonitoringDashWeb.UI.Tabs

  test "renders tab buttons with panel relationships and change event payloads" do
    document =
      render_component(&Tabs.render/1,
        id: "asset-tabs",
        active: "activity",
        change_event: "focus_asset_section",
        label: "Asset detail focus",
        panel_id_prefix: "asset-panel",
        tab_id_prefix: "asset-tab",
        tabs: [
          %{value: "overview", label: "Overview"},
          %{value: "activity", label: "Activity"}
        ]
      )
      |> LazyHTML.from_fragment()

    assert document
           |> LazyHTML.query(~s(nav#asset-tabs[role="tablist"][aria-label="Asset detail focus"]))
           |> Enum.any?()

    assert document
           |> LazyHTML.query(
             ~s(button#asset-tab-activity[role="tab"][aria-controls="asset-panel-activity"][phx-click="focus_asset_section"][phx-value-tab="activity"])
           )
           |> Enum.any?()

    assert document
           |> LazyHTML.query("#asset-tab-activity.border-app-accent")
           |> Enum.any?()

    assert document
           |> LazyHTML.query("#asset-tab-overview.border-transparent")
           |> Enum.any?()
  end
end
