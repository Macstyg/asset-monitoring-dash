defmodule AssetMonitoringDashWeb.DashboardLiveTest do
  use AssetMonitoringDashWeb.ConnCase

  import Phoenix.LiveViewTest

  test "renders the asset risk cockpit as a full-width monitor", %{conn: conn} do
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
    assert has_element?(view, "#asset-summary")
    assert has_element?(view, "#asset-summary-visible-count")
    assert has_element?(view, "#asset-summary-value")
    assert has_element?(view, "#asset-summary-at-risk")
    assert has_element?(view, "#asset-summary-highest-ltv")
    assert has_element?(view, "#asset-filters")
    assert has_element?(view, "#filters_query")
    assert has_element?(view, "#filters_risk")
    assert has_element?(view, "#filters_action")
    assert has_element?(view, "#filters_chain")
    assert has_element?(view, "#reset-asset-filters")
    assert has_element?(view, "#asset-row-asset-001")
    assert has_element?(view, "#asset-row-asset-010")
    assert has_element?(view, "#asset-row-asset-012", "Manual review")
    assert has_element?(view, "#asset-row-asset-012", "Illiquid market")
    refute has_element?(view, "#asset-inspection")
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
    assert has_element?(view, "#asset-summary-visible-count", "2")
    assert has_element?(view, "#asset-summary-value", "$29,910")
    assert has_element?(view, "#asset-summary-at-risk", "2")
    assert has_element?(view, "#asset-summary-highest-ltv", "80.1%")
    assert has_element?(view, "#asset-row-asset-002")
    assert has_element?(view, "#asset-row-asset-010")
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

  test "navigates to the selected asset detail page from a row", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> element("#asset-row-asset-003")
    |> render_click()

    assert_redirect(view, ~p"/assets/asset-003")
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
    refute has_element?(view, "#asset-row-asset-001")
  end

  test "filters monitored assets by recommendation action", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#asset-filters", %{
      "filters" => %{
        "query" => "",
        "risk" => "All",
        "action" => "manual_review",
        "chain" => "All chains"
      }
    })
    |> render_change()

    assert has_element?(view, "#asset-count", "8 monitored")
    assert has_element?(view, "#asset-row-asset-001", "Elevated risk")
    assert has_element?(view, "#asset-row-asset-012", "Illiquid market")
    refute has_element?(view, "#asset-row-asset-002")

    view
    |> form("#asset-filters", %{
      "filters" => %{
        "query" => "",
        "risk" => "All",
        "action" => "liquidation_candidate",
        "chain" => "All chains"
      }
    })
    |> render_change()

    assert has_element?(view, "#asset-count", "1 monitored")
    assert has_element?(view, "#asset-row-asset-002", "Liquidation candidate")
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
    refute has_element?(view, "#asset-row-asset-001")
  end

  test "shows an empty state when asset filters have no matches", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#asset-filters", %{
      "filters" => %{"query" => "missing asset", "risk" => "All", "chain" => "All chains"}
    })
    |> render_change()

    assert has_element?(view, "#asset-count", "0 monitored")
    assert has_element?(view, "#asset-summary-visible-count", "0")
    assert has_element?(view, "#asset-summary-value", "$0")
    assert has_element?(view, "#asset-summary-at-risk", "0")
    assert has_element?(view, "#asset-summary-highest-ltv", "0.0%")
    assert has_element?(view, "#asset-list-empty", "No assets match this filter.")
    refute has_element?(view, "#asset-row-asset-001")
    refute has_element?(view, "#asset-inspection")
  end

  test "resets asset filters", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#asset-filters", %{
      "filters" => %{"query" => "mech", "risk" => "Critical", "chain" => "Arbitrum"}
    })
    |> render_change()

    assert has_element?(view, "#asset-count", "1 monitored")

    view
    |> element("#reset-asset-filters")
    |> render_click()

    assert has_element?(view, "#asset-count", "12 monitored")
    assert has_element?(view, "#asset-row-asset-001")
    assert has_element?(view, "#asset-row-asset-010")
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

    for _index <- 1..3 do
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
