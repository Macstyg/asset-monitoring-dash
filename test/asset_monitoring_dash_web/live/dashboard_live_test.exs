defmodule AssetMonitoringDashWeb.DashboardLiveTest do
  use AssetMonitoringDashWeb.ConnCase

  import Phoenix.LiveViewTest

  test "renders the asset risk cockpit", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#dashboard-shell")
    assert has_element?(view, "#metric-strip")
    assert has_element?(view, "#collateral-value-card")
    assert has_element?(view, "#active-loans-card")
    assert has_element?(view, "#weighted-apy-card")
    assert has_element?(view, "#risk-score-card")
    assert has_element?(view, "#asset-monitor")
    assert has_element?(view, "#asset-count")
    assert has_element?(view, "#asset-list")
    assert has_element?(view, "#asset-list-rows")
    assert has_element?(view, "#risk-filter")
    assert has_element?(view, "#asset-row-asset-001")
    assert has_element?(view, "#asset-row-asset-010")
    assert has_element?(view, "#asset-inspection")
    assert has_element?(view, "#event-feed")
    assert has_element?(view, "#event-list")
    assert has_element?(view, "#event-row-event-001")
    assert has_element?(view, "#event-row-event-004")
  end

  test "filters monitored assets by risk band", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> element("#risk-filter-critical")
    |> render_click()

    assert has_element?(view, "#asset-count", "2 monitored")
    assert has_element?(view, "#asset-row-asset-002")
    assert has_element?(view, "#asset-row-asset-010")
    assert has_element?(view, "#asset-inspection", "Citadel Founder Parcel")
    refute has_element?(view, "#asset-row-asset-001")

    view
    |> element("#risk-filter-all")
    |> render_click()

    assert has_element?(view, "#asset-count", "12 monitored")
    assert has_element?(view, "#asset-row-asset-001")
    assert has_element?(view, "#asset-row-asset-010")
  end

  test "selects an asset for inspection", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#asset-inspection", "Aegis Dragon Helm")

    view
    |> element("#asset-row-asset-010")
    |> render_click()

    assert has_element?(view, "#asset-inspection", "Ancient Mech Core")
    assert has_element?(view, "#asset-inspection", "$7,020")
    assert has_element?(view, "#asset-inspection", "92/100")
  end
end
