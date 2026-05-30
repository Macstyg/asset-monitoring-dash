defmodule AssetMonitoringDashWeb.AssetLiveTest do
  use AssetMonitoringDashWeb.ConnCase

  import Phoenix.LiveViewTest

  alias AssetMonitoringDash.EventStore

  test "renders a dedicated asset inspection page", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/assets/asset-001")

    assert has_element?(view, "#asset-detail-shell")
    assert has_element?(view, "#back-to-dashboard")
    assert has_element?(view, "#asset-inspection", "Aegis Dragon Helm")
    assert has_element?(view, ~s(#asset-inspection img[src="/images/assets/dragon-helm.svg"]))
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
    assert has_element?(view, "#investigation-brief")
    assert has_element?(view, "#investigation-primary-question", "analyst intervention")
    assert has_element?(view, "#investigation-recommendation", "Manual review")
    assert has_element?(view, "#investigation-review-state", "Unreviewed")
    assert has_element?(view, "#investigation-next-step", "System recommends analyst review")
    assert has_element?(view, "#investigation-buffer", "59.7% LTV")
    assert has_element?(view, "#investigation-data-confidence", "Fresh oracle")
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
    assert has_element?(view, "#asset-event-list-empty", "No recorded activity")
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

  test "keeps a safe return target for the dashboard", %{conn: conn} do
    {:ok, view, _html} =
      live(
        conn,
        ~p"/assets/asset-001?#{%{return_to: "/?actions=manual_review&chains=Arbitrum&dir=desc&operator_states=unreviewed&query=mech&risks=Critical&sort=risk"}}"
      )

    assert has_element?(
             view,
             ~s(#back-to-dashboard[href="/?actions=manual_review&chains=Arbitrum&dir=desc&operator_states=unreviewed&query=mech&risks=Critical&sort=risk"])
           )

    {:ok, external_view, _html} =
      live(conn, ~p"/assets/asset-001?#{%{return_to: "https://example.com/phish"}}")

    assert has_element?(external_view, ~s(#back-to-dashboard[href="/"]))
  end

  test "loads persisted activity only for the inspected asset", %{conn: conn} do
    asset = %{
      id: "asset-001",
      name: "Aegis Dragon Helm",
      chain: "Polygon",
      ltv_percent: 67.8
    }

    other_asset = %{
      id: "asset-002",
      name: "Citadel Founder Parcel",
      chain: "Ethereum",
      ltv_percent: 85.5
    }

    EventStore.push_price_shock_event(other_asset, 12)
    EventStore.push_price_shock_event(asset, 12)

    {:ok, view, _html} = live(conn, ~p"/assets/asset-001")

    assert has_element?(view, "#asset-event-count", "1 events")
    assert has_element?(view, "#asset-event-row-event-shock-asset-001", "Price shock applied")
    refute has_element?(view, "#asset-event-row-event-shock-asset-002")
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

  test "persists operator state for dashboard filtering", %{conn: conn} do
    {:ok, detail_view, _html} = live(conn, ~p"/assets/asset-001")

    detail_view
    |> element("#mark-asset-reviewed")
    |> render_click()

    {:ok, dashboard_view, _html} = live(conn, ~p"/")

    dashboard_view
    |> form("#asset-filters", %{
      "filters" => %{
        "query" => "",
        "risks" => [""],
        "actions" => [""],
        "operator_states" => ["reviewed"],
        "chains" => [""]
      }
    })
    |> render_change()

    assert has_element?(dashboard_view, "#asset-count", "1 monitored")
    assert has_element?(dashboard_view, "#event-row-event-review-reviewed-asset-001")

    assert has_element?(
             dashboard_view,
             "#event-row-event-review-reviewed-asset-001",
             "Position reviewed"
           )

    assert has_element?(dashboard_view, "#asset-row-asset-001", "Reviewed")
    refute has_element?(dashboard_view, "#asset-row-asset-003")
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

  test "keeps an applied price shock visible across pages", %{conn: conn} do
    {:ok, detail_view, _html} = live(conn, ~p"/assets/asset-001")

    detail_view
    |> element("#apply-price-shock")
    |> render_click()

    {:ok, remounted_detail_view, _html} = live(conn, ~p"/assets/asset-001")

    assert has_element?(remounted_detail_view, "#asset-inspection", "$4,277")
    assert has_element?(remounted_detail_view, "#asset-ltv-trend-latest", "67.8%")
    assert has_element?(remounted_detail_view, "#apply-price-shock[disabled]", "Shock applied")
    assert has_element?(remounted_detail_view, "#asset-event-count", "1 events")
    assert has_element?(remounted_detail_view, "#asset-event-row-event-shock-asset-001")

    {:ok, dashboard_view, _html} = live(conn, ~p"/")

    dashboard_view
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

    assert has_element?(dashboard_view, "#event-row-event-shock-asset-001", "Price shock applied")
    assert has_element?(dashboard_view, "#asset-row-asset-001", "$4,277")
    assert has_element?(dashboard_view, "#asset-row-asset-001", "67.8%")

    remounted_detail_view
    |> element("#reset-asset-scenario")
    |> render_click()

    {:ok, reset_dashboard_view, _html} = live(conn, ~p"/")

    reset_dashboard_view
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

    assert has_element?(reset_dashboard_view, "#asset-row-asset-001", "$4,860")
    assert has_element?(reset_dashboard_view, "#asset-row-asset-001", "59.7%")
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
