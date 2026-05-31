defmodule AssetMonitoringDashWeb.DashboardLive.ScenarioTest do
  use AssetMonitoringDashWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  test "shows and resets active asset scenarios", %{conn: conn} do
    AssetMonitoringDash.AssetScenarioStore.apply_price_shock("asset-001")
    AssetMonitoringDash.ReviewStore.mark_reviewed("asset-001")

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#active-scenario-banner")
    assert has_element?(view, "#active-scenario-count", "1 active scenario")
    assert has_element?(view, "#reset-asset-scenarios")

    view
    |> form("#asset-filters", %{
      "filters" => %{
        "query" => "aegis",
        "risks" => [""],
        "actions" => [""],
        "operator_states" => [""],
        "chains" => [""]
      }
    })
    |> render_change()

    assert has_element?(view, "#asset-count", "50 monitored")
    assert has_element?(view, "#asset-row-asset-001", "$4,277")
    assert has_element?(view, "#asset-row-asset-001", "67.8%")
    assert has_element?(view, "#asset-scenario-asset-001", "Price shock")
    assert has_element?(view, "#asset-row-asset-001", "Reviewed")

    view
    |> element("#reset-asset-scenarios")
    |> render_click()

    refute has_element?(view, "#active-scenario-banner")
    refute has_element?(view, "#asset-scenario-asset-001")
    assert has_element?(view, "#event-row-event-reset-asset-001", "Scenario reset")
    assert has_element?(view, "#asset-row-asset-001", "$4,860")
    assert has_element?(view, "#asset-row-asset-001", "59.7%")
    assert has_element?(view, "#asset-row-asset-001", "Unreviewed")
  end
end
