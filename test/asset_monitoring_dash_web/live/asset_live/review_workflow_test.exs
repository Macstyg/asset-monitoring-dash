defmodule AssetMonitoringDashWeb.AssetLive.ReviewWorkflowTest do
  use AssetMonitoringDashWeb.ConnCase, async: false

  setup :register_and_log_in_user

  import Phoenix.LiveViewTest
  import AssetMonitoringDashWeb.AssetLiveTestHelpers

  test "updates operator review state without changing system recommendation", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/assets/asset-001")

    assert has_element?(view, "#risk-recommendation-label", "Manual review")
    assert has_element?(view, "#operator-review-state-label", "Unreviewed")
    refute has_element?(view, "#mark-asset-reviewed[disabled]")
    refute has_element?(view, "#escalate-asset-review[disabled]")

    submit_review_action(view, :reviewed)

    assert has_element?(view, "#risk-recommendation-label", "Manual review")
    assert has_element?(view, "#operator-review-state-label", "Reviewed")
    assert has_element?(view, "#mark-asset-reviewed[disabled]")

    view
    |> element("#asset-focus-activity")
    |> render_click()

    assert assert_patch(view) == asset_path("asset-001", "focus=activity")
    assert has_element?(view, "#review-history-count", "1")
    assert has_element?(view, "#review-history-list", "Reviewed")
    assert has_element?(view, "#review-history-list", "by Operator")
    assert has_element?(view, "#review-history-list", "Signal reviewed")
    assert has_element?(view, "#asset-event-count", "1 events")
    assert has_element?(view, "#asset-event-row-event-review-reviewed-asset-001")

    assert has_element?(
             view,
             "#asset-event-row-event-review-reviewed-asset-001",
             "Position reviewed"
           )
  end

  test "updates presenter story state after review completion", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/assets/asset-001?demo=story")

    assert has_element?(view, "#asset-demo-story-state", "Inspection phase")
    assert has_element?(view, "#asset-demo-step-review", "Pending")
    assert has_element?(view, "#asset-demo-step-audit", "Pending")

    submit_review_action(view, :reviewed)

    assert has_element?(view, "#asset-demo-story-state", "Loop closed")
    assert has_element?(view, "#asset-demo-review-state", "Reviewed")
    assert has_element?(view, "#asset-demo-step-review", "Done")
    assert has_element?(view, "#asset-demo-step-audit", "Ready")

    view
    |> element("#asset-demo-open-audit")
    |> render_click()

    assert assert_patch(view) == asset_path("asset-001", "demo=story&focus=activity")
    assert has_element?(view, "#review-history-count", "1")
    assert has_element?(view, "#review-history-list", "Reviewed")
  end

  test "resets demo runtime and returns to the dashboard from presenter story", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/assets/asset-001?demo=story")

    submit_review_action(view, :reviewed)

    assert has_element?(view, "#asset-demo-story-state", "Loop closed")

    view
    |> element("#asset-demo-reset-replay")
    |> render_click()

    assert_redirect(view, ~p"/")
  end

  test "persists operator state for dashboard filtering", %{conn: conn} do
    {:ok, detail_view, _html} = live(conn, ~p"/assets/asset-001")

    submit_review_action(detail_view, :reviewed)

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

    submit_review_action(view, :escalated,
      reason: "borrower_follow_up",
      note: "Need borrower context."
    )

    assert has_element?(view, "#risk-recommendation-label", "Watch")
    assert has_element?(view, "#operator-review-state-label", "Escalated")
    assert has_element?(view, "#escalate-asset-review[disabled]")

    view
    |> element("#asset-focus-activity")
    |> render_click()

    assert assert_patch(view) == asset_path("asset-003", "focus=activity")
    assert has_element?(view, "#review-history-count", "1")
    assert has_element?(view, "#review-history-list", "Escalated")
    assert has_element?(view, "#review-history-list", "Borrower follow-up")
    assert has_element?(view, "#review-history-list", "Need borrower context.")
    assert has_element?(view, "#asset-event-row-event-review-escalated-asset-003")

    assert has_element?(
             view,
             "#asset-event-row-event-review-escalated-asset-003",
             "Review escalated"
           )

    assert has_element?(
             view,
             "#asset-event-row-event-review-escalated-asset-003",
             "Borrower follow-up"
           )

    assert has_element?(
             view,
             "#asset-event-row-event-review-escalated-asset-003",
             "Need borrower context."
           )
  end

  test "resets operator review state when a reviewed asset scenario changes", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/assets/asset-001")

    submit_review_action(view, :reviewed)

    assert has_element?(view, "#operator-review-state-label", "Reviewed")

    view
    |> element("#apply-price-shock")
    |> render_click()

    assert has_element?(view, "#risk-recommendation-label", "Manual review")
    assert has_element?(view, "#operator-review-state-label", "Unreviewed")

    view
    |> element("#asset-focus-activity")
    |> render_click()

    assert assert_patch(view) == asset_path("asset-001", "focus=activity")
    assert has_element?(view, "#review-history-count", "2")
    assert has_element?(view, "#review-history-list", "Scenario changed")
    assert has_element?(view, "#review-history-list", "by System")
    assert has_element?(view, "#asset-event-row-event-review-unreviewed-asset-001")

    assert has_element?(
             view,
             "#asset-event-row-event-review-unreviewed-asset-001",
             "Review state reset"
           )
  end
end
