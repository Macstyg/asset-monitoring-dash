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
    assert has_element?(view, "#asset-summary")
    assert has_element?(view, "#asset-summary-visible-count")
    assert has_element?(view, "#asset-summary-value")
    assert has_element?(view, "#asset-summary-at-risk")
    assert has_element?(view, "#asset-summary-highest-ltv")
    assert has_element?(view, "#asset-filters")
    assert has_element?(view, "#filters_query")
    assert has_element?(view, "#filters_risk")
    assert has_element?(view, "#filters_chain")
    assert has_element?(view, "#reset-asset-filters")
    assert has_element?(view, "#asset-row-asset-001")
    assert has_element?(view, "#asset-row-asset-010")
    assert has_element?(view, "#asset-inspection")
    assert has_element?(view, "#risk-explanation")
    assert has_element?(view, "#risk-explanation-headline", "Collateral buffer needs attention.")
    assert has_element?(view, "#risk-reason-ltv_pressure")
    assert has_element?(view, "#risk-reason-health_factor")
    assert has_element?(view, "#risk-reason-valuation_gap")
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
    assert has_element?(view, "#asset-inspection", "Aegis Dragon Helm")
  end

  test "selects an asset for inspection", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#asset-inspection", "Aegis Dragon Helm")

    view
    |> element("#asset-row-asset-010")
    |> render_click()

    assert has_element?(view, "#asset-inspection", "Ancient Mech Core")
    assert has_element?(view, "#asset-inspection", "$7,020")
    assert has_element?(view, "#asset-inspection", "94/100")
  end

  test "applies a price shock to the selected asset", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#asset-row-asset-001", "$4,860")
    assert has_element?(view, "#asset-row-asset-001", "59.7%")
    refute has_element?(view, "#apply-price-shock[disabled]")
    assert has_element?(view, "#reset-asset-scenario[disabled]")

    view
    |> element("#apply-price-shock")
    |> render_click()

    assert has_element?(view, "#asset-row-asset-001", "$4,277")
    assert has_element?(view, "#asset-row-asset-001", "67.8%")
    assert has_element?(view, "#asset-inspection", "$4,277")
    assert has_element?(view, "#asset-inspection", "80/100")
    assert has_element?(view, "#risk-reason-ltv_pressure", "Rising LTV")
    assert has_element?(view, "#risk-reason-ltv_pressure", "67.8%")
    assert has_element?(view, "#asset-summary-value", "$68,902")
    assert has_element?(view, "#apply-price-shock[disabled]", "Shock applied")
    assert has_element?(view, "#event-row-event-shock-asset-001")
    assert has_element?(view, "#event-row-event-shock-asset-001", "Price shock applied")
    assert has_element?(view, "#event-row-event-shock-asset-001", "67.8%")

    render_click(view, :apply_price_shock)

    assert has_element?(view, "#asset-row-asset-001", "$4,277")
    assert has_element?(view, "#asset-summary-value", "$68,902")
  end

  test "resets a shocked asset scenario", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> element("#apply-price-shock")
    |> render_click()

    view
    |> element("#reset-asset-scenario")
    |> render_click()

    assert has_element?(view, "#asset-row-asset-001", "$4,860")
    assert has_element?(view, "#asset-row-asset-001", "59.7%")
    assert has_element?(view, "#asset-inspection", "$4,860")
    assert has_element?(view, "#asset-inspection", "70/100")
    assert has_element?(view, "#asset-summary-value", "$69,485")
    refute has_element?(view, "#apply-price-shock[disabled]")
    assert has_element?(view, "#reset-asset-scenario[disabled]")
    assert has_element?(view, "#event-row-event-reset-asset-001")
    assert has_element?(view, "#event-row-event-reset-asset-001", "Scenario reset")
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
