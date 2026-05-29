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
    assert has_element?(view, "#asset-filters")
    assert has_element?(view, "#filters_query")
    assert has_element?(view, "#filters_risk")
    assert has_element?(view, "#filters_chain")
    assert has_element?(view, "#asset-row-asset-001")
    assert has_element?(view, "#asset-row-asset-010")
    assert has_element?(view, "#asset-inspection")
    assert has_element?(view, "#event-feed")
    assert has_element?(view, "#event-count", "5 events")
    assert has_element?(view, "#event-feed-state", "streaming")
    assert has_element?(view, "#event-list")
    assert has_element?(view, "#event-row-event-001")
    assert has_element?(view, "#event-row-event-004")
  end

  test "filters monitored assets by risk band", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#asset-filters", %{
      "filters" => %{"query" => "", "risk" => "Critical", "chain" => "All chains"}
    })
    |> render_change()

    assert has_element?(view, "#asset-count", "2 monitored")
    assert has_element?(view, "#asset-row-asset-002")
    assert has_element?(view, "#asset-row-asset-010")
    assert has_element?(view, "#asset-inspection", "Citadel Founder Parcel")
    refute has_element?(view, "#asset-row-asset-001")

    view
    |> form("#asset-filters", %{
      "filters" => %{"query" => "", "risk" => "All", "chain" => "All chains"}
    })
    |> render_change()

    assert has_element?(view, "#asset-count", "12 monitored")
    assert has_element?(view, "#asset-row-asset-001")
    assert has_element?(view, "#asset-row-asset-010")
  end

  test "filters monitored assets by chain", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#asset-filters", %{
      "filters" => %{"query" => "", "risk" => "All", "chain" => "Arbitrum"}
    })
    |> render_change()

    assert has_element?(view, "#asset-count", "2 monitored")
    assert has_element?(view, "#asset-row-asset-005")
    assert has_element?(view, "#asset-row-asset-010")
    assert has_element?(view, "#asset-inspection", "Genesis Mana Vault")
    refute has_element?(view, "#asset-row-asset-001")
  end

  test "combines risk and chain filters", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#asset-filters", %{
      "filters" => %{"query" => "", "risk" => "Critical", "chain" => "All chains"}
    })
    |> render_change()

    view
    |> form("#asset-filters", %{
      "filters" => %{"query" => "", "risk" => "Critical", "chain" => "Arbitrum"}
    })
    |> render_change()

    assert has_element?(view, "#asset-count", "1 monitored")
    assert has_element?(view, "#asset-row-asset-010")
    assert has_element?(view, "#asset-inspection", "Ancient Mech Core")
    refute has_element?(view, "#asset-row-asset-002")
  end

  test "filters monitored assets by search query", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#asset-filters", %{
      "filters" => %{"query" => "mech", "risk" => "All", "chain" => "All chains"}
    })
    |> render_change()

    assert has_element?(view, "#asset-count", "1 monitored")
    assert has_element?(view, "#asset-row-asset-010")
    assert has_element?(view, "#asset-inspection", "Ancient Mech Core")
    refute has_element?(view, "#asset-row-asset-001")
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

  test "pushes and pauses demo events", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> element("#push-demo-event")
    |> render_click()

    assert has_element?(view, "#event-count", "6 events")
    assert has_element?(view, "#event-row-event-live-1")
    assert has_element?(view, "#event-list", "Oracle heartbeat")

    view
    |> element("#toggle-event-feed")
    |> render_click()

    assert has_element?(view, "#event-feed-state", "paused")
    assert has_element?(view, "#toggle-event-feed", "Resume feed")
  end

  test "keeps the visible event feed bounded", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    for _ <- 1..3 do
      view
      |> element("#push-demo-event")
      |> render_click()
    end

    assert has_element?(view, "#event-count", "6 events")
    assert has_element?(view, "#event-row-event-live-3")
    assert has_element?(view, "#event-row-event-live-3", "now")
    assert has_element?(view, "#event-row-event-live-2", "4s ago")
    assert has_element?(view, "#event-row-event-live-1", "8s ago")
    refute has_element?(view, "#event-row-event-005")
  end
end
