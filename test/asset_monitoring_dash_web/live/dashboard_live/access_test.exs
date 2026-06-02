defmodule AssetMonitoringDashWeb.DashboardLive.AccessTest do
  use AssetMonitoringDashWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "renders a public view-only dashboard for anonymous users", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#dashboard-shell")
    assert has_element?(view, "#dashboard-status", "Public preview")
    assert has_element?(view, "#dashboard-status", "View-only")
    assert has_element?(view, "#view-only-demo-banner")
    assert has_element?(view, "#view-only-login-link", "Log in")
    assert has_element?(view, "#view-only-register-link", "Register")
    assert has_element?(view, "#metric-strip")
    assert has_element?(view, "#dashboard-analytics")
    assert has_element?(view, "#asset-monitor")
    assert has_element?(view, "#event-feed")
    refute has_element?(view, "#demo-walkthrough")
    refute has_element?(view, "#simulator-status")
    assert has_element?(view, "#asset-row-asset-010[phx-click=\"select_asset\"]")
  end

  test "renders public asset detail for anonymous users", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/assets/asset-001")

    assert has_element?(view, "#asset-detail-shell")
    assert has_element?(view, "#asset-detail-shell", "Aegis Dragon Helm")
    assert has_element?(view, "#asset-inspection")
    assert has_element?(view, "#investigation-brief")
    assert has_element?(view, "#asset-read-only-actions")
    assert has_element?(view, "#asset-read-only-login-link", "Log in")
    assert has_element?(view, "#asset-read-only-register-link", "Register")
    refute has_element?(view, "#asset-scenario-controls")
    refute has_element?(view, "#review-action-form")
  end

  test "renders dashboard for authenticated users", %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#dashboard-shell")
    assert has_element?(view, "#dashboard-status", "Database-backed demo")
    assert has_element?(view, "#dashboard-status", "Live simulator")
    assert has_element?(view, "#demo-walkthrough")
    assert has_element?(view, "#simulator-status")
    refute has_element?(view, "#view-only-demo-banner")
    assert has_element?(view, "#asset-row-asset-010[phx-click=\"select_asset\"]")
  end
end
