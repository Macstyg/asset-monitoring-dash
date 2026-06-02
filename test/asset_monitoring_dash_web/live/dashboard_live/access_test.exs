defmodule AssetMonitoringDashWeb.DashboardLive.AccessTest do
  use AssetMonitoringDashWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  test "redirects anonymous users from the dashboard to login", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/")
  end

  test "redirects anonymous users from asset detail to login", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/assets/asset-001")
  end

  test "renders dashboard for authenticated users", %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#dashboard-shell")
  end
end
