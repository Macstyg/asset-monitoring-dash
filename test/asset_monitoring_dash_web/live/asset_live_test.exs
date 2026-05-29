defmodule AssetMonitoringDashWeb.AssetLiveTest do
  use AssetMonitoringDashWeb.ConnCase

  import Phoenix.LiveViewTest

  test "renders a dedicated asset inspection page", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/assets/asset-001")

    assert has_element?(view, "#asset-detail-shell")
    assert has_element?(view, "#back-to-dashboard")
    assert has_element?(view, "#asset-inspection", "Aegis Dragon Helm")
    assert has_element?(view, "#asset-context-strip")
    assert has_element?(view, "#asset-context-chain", "Polygon")
    assert has_element?(view, "#asset-context-game", "Skyforge Arena")
    assert has_element?(view, "#asset-context-rarity", "Legendary")
    assert has_element?(view, "#asset-context-type", "NFT")
    assert has_element?(view, "#asset-context-value", "$4,860 collateral")
    assert has_element?(view, "#asset-context-loan", "$2,900 borrowed")
    assert has_element?(view, "#asset-context-oracle", "Fresh")
    assert has_element?(view, "#asset-context-liquidity", "Deep")
    assert has_element?(view, "#asset-context-depth", "$42,000 market depth")
    assert has_element?(view, "#asset-detail-recommendation", "Manual review")
    assert has_element?(view, "#asset-detail-review-state", "Unreviewed")
    assert has_element?(view, "#review-workflow-panel")
    assert has_element?(view, "#risk-recommendation-label", "Manual review")
    assert has_element?(view, "#risk-recommendation-reasons")
    assert has_element?(view, "#risk-recommendation-reason-elevated_risk", "Elevated risk")
    assert has_element?(view, "#operator-review-state-label", "Unreviewed")
    assert has_element?(view, "#asset-inspection", "Oracle")
    assert has_element?(view, "#asset-inspection", "Fresh")
    assert has_element?(view, "#asset-inspection", "24s ago")
    assert has_element?(view, "#asset-inspection", "Liquidity")
    assert has_element?(view, "#asset-inspection", "Deep")
    assert has_element?(view, "#asset-inspection", "$42,000 depth")
    assert has_element?(view, "#risk-explanation")
    assert has_element?(view, "#asset-ltv-trend")
    assert has_element?(view, "#asset-ltv-trend-latest", "59.7%")
    assert has_element?(view, "#asset-ltv-trend-delta", "+3.2 pts")
    assert has_element?(view, "#risk-explanation-headline", "Collateral buffer needs attention.")
    assert has_element?(view, "#risk-reason-ltv_pressure")
    assert has_element?(view, "#risk-reason-health_factor")
    assert has_element?(view, "#risk-reason-valuation_gap")
    assert has_element?(view, "#asset-activity")
    assert has_element?(view, "#asset-event-count", "0 events")
    assert has_element?(view, "#asset-event-list-empty", "No activity")
  end

  test "renders oracle and liquidity-driven recommendation details", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/assets/asset-012")

    assert has_element?(view, "#asset-inspection", "Stormforged Battle Pass")
    assert has_element?(view, "#asset-inspection", "Fresh")
    assert has_element?(view, "#asset-inspection", "Illiquid")
    assert has_element?(view, "#asset-inspection", "$3,900 depth")
    assert has_element?(view, "#risk-recommendation-label", "Manual review")
    assert has_element?(view, "#risk-recommendation-reason-illiquid_market", "Illiquid market")
  end

  test "updates operator review state without changing system recommendation", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/assets/asset-001")

    assert has_element?(view, "#risk-recommendation-label", "Manual review")
    assert has_element?(view, "#operator-review-state-label", "Unreviewed")
    refute has_element?(view, "#mark-asset-reviewed[disabled]")
    refute has_element?(view, "#escalate-asset-review[disabled]")

    view
    |> element("#mark-asset-reviewed")
    |> render_click()

    assert has_element?(view, "#risk-recommendation-label", "Manual review")
    assert has_element?(view, "#operator-review-state-label", "Reviewed")
    assert has_element?(view, "#mark-asset-reviewed[disabled]")
    assert has_element?(view, "#asset-event-count", "1 events")
    assert has_element?(view, "#asset-event-row-event-review-reviewed-asset-001")

    assert has_element?(
             view,
             "#asset-event-row-event-review-reviewed-asset-001",
             "Position reviewed"
           )
  end

  test "escalates a different asset inspection session", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/assets/asset-003")

    assert has_element?(view, "#asset-inspection", "Neon Pulse Racer")
    assert has_element?(view, "#risk-recommendation-label", "Watch")
    assert has_element?(view, "#operator-review-state-label", "Unreviewed")
    refute has_element?(view, "#escalate-asset-review[disabled]")

    view
    |> element("#escalate-asset-review")
    |> render_click()

    assert has_element?(view, "#risk-recommendation-label", "Watch")
    assert has_element?(view, "#operator-review-state-label", "Escalated")
    assert has_element?(view, "#escalate-asset-review[disabled]")
    assert has_element?(view, "#asset-event-row-event-review-escalated-asset-003")

    assert has_element?(
             view,
             "#asset-event-row-event-review-escalated-asset-003",
             "Review escalated"
           )
  end

  test "resets operator review state when a reviewed asset scenario changes", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/assets/asset-001")

    view
    |> element("#mark-asset-reviewed")
    |> render_click()

    assert has_element?(view, "#operator-review-state-label", "Reviewed")

    view
    |> element("#apply-price-shock")
    |> render_click()

    assert has_element?(view, "#risk-recommendation-label", "Manual review")
    assert has_element?(view, "#operator-review-state-label", "Unreviewed")
  end

  test "applies a price shock to the inspected asset", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/assets/asset-001")

    assert has_element?(view, "#asset-inspection", "$4,860")
    assert has_element?(view, "#asset-ltv-trend-latest", "59.7%")
    refute has_element?(view, "#apply-price-shock[disabled]")
    assert has_element?(view, "#reset-asset-scenario[disabled]")

    view
    |> element("#apply-price-shock")
    |> render_click()

    assert has_element?(view, "#asset-inspection", "$4,277")
    assert has_element?(view, "#asset-inspection", "80/100")
    assert has_element?(view, "#asset-ltv-trend-latest", "67.8%")
    assert has_element?(view, "#asset-ltv-trend-delta", "+11.3 pts")
    assert has_element?(view, "#risk-reason-ltv_pressure", "Rising LTV")
    assert has_element?(view, "#risk-reason-ltv_pressure", "67.8%")
    assert has_element?(view, "#apply-price-shock[disabled]", "Shock applied")
    assert has_element?(view, "#asset-event-row-event-shock-asset-001")
    assert has_element?(view, "#asset-event-row-event-shock-asset-001", "Price shock applied")
    assert has_element?(view, "#asset-event-row-event-shock-asset-001", "67.8%")

    render_click(view, :apply_price_shock)

    assert has_element?(view, "#asset-inspection", "$4,277")
    assert has_element?(view, "#asset-event-count", "1 events")
  end

  test "resets a shocked asset scenario", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/assets/asset-001")

    view
    |> element("#apply-price-shock")
    |> render_click()

    view
    |> element("#reset-asset-scenario")
    |> render_click()

    assert has_element?(view, "#asset-inspection", "$4,860")
    assert has_element?(view, "#asset-inspection", "70/100")
    assert has_element?(view, "#asset-ltv-trend-latest", "59.7%")
    assert has_element?(view, "#asset-ltv-trend-delta", "+3.2 pts")
    refute has_element?(view, "#apply-price-shock[disabled]")
    assert has_element?(view, "#reset-asset-scenario[disabled]")
    assert has_element?(view, "#asset-event-row-event-reset-asset-001")
    assert has_element?(view, "#asset-event-row-event-reset-asset-001", "Scenario reset")
  end
end
