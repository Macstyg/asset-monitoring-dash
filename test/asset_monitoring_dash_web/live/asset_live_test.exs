defmodule AssetMonitoringDashWeb.AssetLiveTest do
  use AssetMonitoringDashWeb.ConnCase

  import Phoenix.LiveViewTest

  alias AssetMonitoringDash.ActivityLog
  alias AssetMonitoringDash.ReviewState

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

    ActivityLog.record_price_shock(other_asset, 12)
    ActivityLog.record_price_shock(asset, 12)

    {:ok, view, _html} = live(conn, ~p"/assets/asset-001?focus=activity")

    assert has_element?(view, "#asset-event-count", "1 events")
    assert has_element?(view, "#asset-event-row-event-shock-asset-001", "Price shock applied")
    assert has_element?(view, "#asset-event-row-event-shock-asset-001", "Scenario")
    assert has_element?(view, "#asset-event-row-event-shock-asset-001", "Critical")
    assert has_element?(view, "#asset-event-row-event-shock-asset-001", "by Scenario engine")
    refute has_element?(view, "#asset-event-row-event-shock-asset-002")
  end

  test "filters asset activity by event source", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/assets/asset-001")

    submit_review_action(view, :reviewed, reason: "oracle_checked", note: "Floor feed checked.")

    view
    |> element("#apply-price-shock")
    |> render_click()

    view
    |> element("#asset-focus-activity")
    |> render_click()

    assert assert_patch(view) == asset_path("asset-001", "focus=activity")

    assert has_element?(view, "#asset-event-count", "2 events")
    assert has_element?(view, "#asset-event-row-event-review-reviewed-asset-001")

    assert has_element?(
             view,
             "#asset-event-row-event-review-reviewed-asset-001",
             "Oracle checked"
           )

    assert has_element?(
             view,
             "#asset-event-row-event-review-reviewed-asset-001",
             "Floor feed checked."
           )

    assert has_element?(view, "#asset-event-row-event-shock-asset-001")

    view
    |> form("#asset-activity-filters", %{
      "asset_event_filters" => %{
        "sources" => ["scenario"],
        "source_option_query" => ""
      }
    })
    |> render_change()

    patch = assert_patch(view)
    params = patch_query_params(patch)

    assert URI.parse(patch).path == asset_path("asset-001")
    assert params["activity_sources"] == "scenario"
    assert params["focus"] == "activity"
    assert has_element?(view, "#asset-event-count", "1 events")
    assert has_element?(view, "#active-filter-asset-event-sources-scenario", "Scenario")
    assert has_element?(view, "#asset-event-row-event-shock-asset-001")
    refute has_element?(view, "#asset-event-row-event-review-reviewed-asset-001")

    view
    |> element("#active-filter-asset-event-sources-scenario")
    |> render_click()

    assert assert_patch(view) == asset_path("asset-001", "focus=activity")
    assert has_element?(view, "#asset-event-count", "2 events")
    refute has_element?(view, "#active-filter-asset-event-sources-scenario")
  end

  test "loads and patches asset detail focus state from the URL", %{conn: conn} do
    {:ok, view, _html} =
      live(conn, ~p"/assets/asset-001?activity_sources=scenario&focus=activity")

    assert has_element?(view, "#active-filter-asset-event-sources-scenario", "Scenario")
    assert has_element?(view, "#asset-focus-activity", "Activity")

    view
    |> element("#asset-focus-related")
    |> render_click()

    patch = assert_patch(view)
    params = patch_query_params(patch)

    assert URI.parse(patch).path == asset_path("asset-001")
    assert params["activity_sources"] == "scenario"
    assert params["focus"] == "related"
  end

  test "loads asset activity source filters from the URL", %{conn: conn} do
    asset = %{
      id: "asset-001",
      name: "Aegis Dragon Helm",
      chain: "Polygon",
      ltv_percent: 67.8
    }

    ActivityLog.record_price_shock(asset, 12)
    ActivityLog.record_review(asset, ReviewState.state(:reviewed))

    {:ok, view, _html} =
      live(conn, ~p"/assets/asset-001?activity_sources=scenario&focus=activity")

    assert has_element?(view, "#asset-event-count", "1 events")
    assert has_element?(view, "#active-filter-asset-event-sources-scenario", "Scenario")
    assert has_element?(view, "#asset-event-row-event-shock-asset-001")
    refute has_element?(view, "#asset-event-row-event-review-reviewed-asset-001")
  end

  test "keeps asset activity source filters on related asset links", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/assets/asset-001?activity_sources=scenario&focus=related")

    [href] =
      view
      |> render()
      |> LazyHTML.from_fragment()
      |> LazyHTML.query("#related-asset-asset-009")
      |> LazyHTML.attribute("href")

    uri = URI.parse(href)
    params = URI.decode_query(uri.query)

    assert uri.path == asset_path("asset-009")
    assert params["activity_sources"] == "scenario"
    assert params["focus"] == "related"
  end

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

    view
    |> element("#asset-focus-activity")
    |> render_click()

    assert assert_patch(view) == asset_path("asset-001", "focus=activity")
    assert has_element?(view, "#asset-event-row-event-shock-asset-001")
    assert has_element?(view, "#asset-event-row-event-shock-asset-001", "Price shock applied")
    assert has_element?(view, "#asset-event-row-event-shock-asset-001", "67.8%")

    render_click(view, :apply_price_shock)

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

    remounted_detail_view
    |> element("#asset-focus-activity")
    |> render_click()

    assert assert_patch(remounted_detail_view) == asset_path("asset-001", "focus=activity")
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
    |> element("#asset-focus-overview")
    |> render_click()

    assert assert_patch(remounted_detail_view) == asset_path("asset-001")

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

    view
    |> element("#asset-focus-activity")
    |> render_click()

    assert assert_patch(view) == asset_path("asset-001", "focus=activity")
    assert has_element?(view, "#asset-event-row-event-reset-asset-001")
    assert has_element?(view, "#asset-event-row-event-reset-asset-001", "Scenario reset")
  end

  defp submit_review_action(view, action, opts \\ []) do
    action = Atom.to_string(action)
    reason = Keyword.get(opts, :reason, "signal_reviewed")
    note = Keyword.get(opts, :note, "")

    view
    |> element("#review-action-form")
    |> render_submit(%{
      "review_action" => %{
        "action" => action,
        "reason" => reason,
        "note" => note
      }
    })
  end

  defp patch_query_params(path) do
    path
    |> URI.parse()
    |> Map.fetch!(:query)
    |> case do
      nil -> %{}
      query -> URI.decode_query(query)
    end
  end

  defp asset_path(code), do: "/assets/#{asset_id(code)}"
  defp asset_path(code, query), do: "#{asset_path(code)}?#{query}"
end
