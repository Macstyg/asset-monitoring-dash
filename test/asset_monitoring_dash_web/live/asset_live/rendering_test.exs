defmodule AssetMonitoringDashWeb.AssetLive.RenderingTest do
  use AssetMonitoringDashWeb.ConnCase, async: true

  setup :register_and_log_in_user

  import Phoenix.LiveViewTest

  test "renders a dedicated asset inspection page", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/assets/asset-001")

    assert has_element?(view, "#asset-detail-shell")
    assert has_element?(view, "#back-to-dashboard")
    assert has_element?(view, "#asset-detail-shell", "Aegis Dragon Helm")
    assert has_element?(view, "#asset-inspection")
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
    assert has_element?(view, ~s(#asset-ltv-trend-chart[phx-hook="EChart"]))
    assert has_element?(view, ~s(#asset-ltv-trend-chart[phx-update="ignore"]))
    assert has_element?(view, "#asset-ltv-trend-latest", "59.7%")
    assert has_element?(view, "#asset-ltv-trend-delta", "+3.2 pts")
    assert has_element?(view, "#risk-explanation-headline", "Collateral buffer needs attention.")
    assert has_element?(view, "#risk-reason-ltv_pressure")
    assert has_element?(view, "#risk-reason-health_factor")
    assert has_element?(view, "#risk-reason-valuation_gap")
    assert has_element?(view, "#review-action-form")
    assert has_element?(view, "#review_action_reason")
    assert has_element?(view, "#review_action_note")
    assert has_element?(view, "#asset-detail-focus-nav.border-b")
    assert has_element?(view, "#asset-focus-overview")
    assert has_element?(view, "#asset-focus-activity")
    assert has_element?(view, "#asset-focus-related")
    assert has_element?(view, "#asset-detail-tab-overview")
    refute has_element?(view, "#asset-detail-tab-activity")
    refute has_element?(view, "#asset-detail-tab-related")
    refute has_element?(view, "#asset-activity")
    refute has_element?(view, "#review-history")
    refute has_element?(view, "#related-assets")
    refute has_element?(view, "#asset-demo-story")
  end

  test "renders presenter story context when opened from the dashboard walkthrough", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/assets/asset-001?demo=story")

    assert has_element?(view, "#asset-demo-story")
    assert has_element?(view, "#asset-demo-story-state", "Inspection phase")
    assert has_element?(view, "#asset-demo-review-state", "Unreviewed")
    assert has_element?(view, "#asset-demo-step-inspect", "Done")
    assert has_element?(view, "#asset-demo-step-review", "Pending")
    assert has_element?(view, "#asset-demo-step-audit", "Pending")

    assert has_element?(
             view,
             ~s(#asset-demo-open-audit[href="/assets/#{asset_id("asset-001")}?demo=story&focus=activity"])
           )

    assert has_element?(view, "#asset-demo-back-dashboard")
    assert has_element?(view, "#asset-demo-reset-replay", "Reset and replay")

    view
    |> element("#asset-focus-activity")
    |> render_click()

    assert assert_patch(view) == "/assets/#{asset_id("asset-001")}?demo=story&focus=activity"
    assert has_element?(view, "#asset-demo-story")
  end

  test "renders the activity tab as an activity workspace", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/assets/asset-001?focus=activity")

    assert has_element?(view, "#asset-focus-activity")
    assert has_element?(view, "#asset-detail-tab-activity")
    assert has_element?(view, "#asset-activity")
    assert has_element?(view, "#asset-activity-filters")
    assert has_element?(view, "#asset-event-count", "0 events")
    assert has_element?(view, "#asset-event-list-empty", "No recorded activity")
    assert has_element?(view, "#review-history")
    assert has_element?(view, "#review-history-count", "0")
    assert has_element?(view, "#review-history-empty", "No operator decisions")
    refute has_element?(view, "#asset-inspection")
    refute has_element?(view, "#related-assets")
  end

  test "renders the related tab as a related-position workspace", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/assets/asset-001?focus=related")

    assert has_element?(view, "#asset-focus-related")
    assert has_element?(view, "#asset-detail-tab-related")
    assert has_element?(view, "#related-assets")
    assert has_element?(view, "#related-asset-asset-009", "Moonwell Guild Charter")

    assert has_element?(
             view,
             ~s(#related-asset-asset-009[href="/assets/#{asset_id("asset-009")}?focus=related"])
           )

    refute has_element?(view, "#asset-inspection")
    refute has_element?(view, "#asset-activity")
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
end
