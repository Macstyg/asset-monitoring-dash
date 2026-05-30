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
    assert has_element?(view, "#theme-toggle")
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
    assert has_element?(view, "#filters_risks_filter")
    assert has_element?(view, "#filters_actions_filter")
    assert has_element?(view, "#filters_operator_states_filter")
    assert has_element?(view, "#filters_chains_filter")
    assert has_element?(view, "#filters_chains_Polygon")
    assert has_element?(view, "#filters_risks_Critical")
    assert has_element?(view, "#reset-asset-filters")
    assert has_element?(view, "#asset-list-sort-value")
    assert has_element?(view, "#asset-list-sort-ltv")
    assert has_element?(view, "#asset-list-sort-risk")
    assert has_element?(view, "#asset-list-sort-action")
    assert has_element?(view, "#asset-mobile-sort-value")
    assert has_element?(view, "#asset-mobile-sort-ltv")
    assert has_element?(view, "#asset-mobile-sort-risk")
    assert has_element?(view, "#asset-mobile-sort-action")
    refute has_element?(view, "#active-filter-chips")
    assert has_element?(view, "#asset-row-asset-001")
    assert has_element?(view, ~s(#asset-row-asset-001 img[src="/images/assets/dragon-helm.svg"]))
    assert has_element?(view, ~s(#asset-row-asset-001 [aria-label="Polygon chain"]))
    assert has_element?(view, "#asset-row-asset-001", "Skyforge Arena")
    assert has_element?(view, "#asset-row-asset-010")
    assert has_element?(view, ~s(#asset-row-asset-010 img[src="/images/assets/mech-core.svg"]))
    assert has_element?(view, ~s(#asset-row-asset-010 [aria-label="Arbitrum chain"]))
    assert has_element?(view, "#asset-row-asset-012", "Manual review")
    assert has_element?(view, "#asset-row-asset-012", "Illiquid market")
    assert has_element?(view, "#asset-row-asset-001", "Unreviewed")
    refute has_element?(view, "#asset-inspection")
    assert has_element?(view, "#event-feed")
    assert has_element?(view, "#event-count", "5 events")
    assert has_element?(view, "#event-feed-state", "streaming")
    assert has_element?(view, "#event-list")
    assert has_element?(view, "#event-row-event-001")
    assert has_element?(view, "#event-row-event-004")
  end

  test "defaults theme selection to the system preference", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)

    assert html =~ ~s'setTheme(localStorage.getItem("phx:theme") || "system")'
    assert html =~ ~s|if (!localStorage.getItem("phx:theme")) setTheme("system")|
  end

  test "filters monitored assets by risk band", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#asset-filters", %{
      "filters" => %{"query" => "", "risks" => ["Critical"], "chains" => [""]}
    })
    |> render_change()

    assert has_element?(view, "#asset-count", "2 monitored")
    assert has_element?(view, "#asset-summary-visible-count", "2")
    assert has_element?(view, "#asset-summary-value", "$29,910")
    assert has_element?(view, "#asset-summary-at-risk", "2")
    assert has_element?(view, "#asset-summary-highest-ltv", "80.1%")
    assert has_element?(view, "#active-filter-chips")
    assert has_element?(view, "#active-filter-risks-critical", "Risk:")
    assert has_element?(view, "#active-filter-risks-critical", "Critical")
    assert has_element?(view, "#asset-row-asset-002")
    assert has_element?(view, "#asset-row-asset-010")
    refute has_element?(view, "#asset-row-asset-001")

    view
    |> form("#asset-filters", %{
      "filters" => %{"query" => "", "risks" => [""], "chains" => [""]}
    })
    |> render_change()

    assert has_element?(view, "#asset-count", "12 monitored")
    refute has_element?(view, "#active-filter-chips")
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
      "filters" => %{"query" => "", "risks" => [""], "chains" => ["Arbitrum"]}
    })
    |> render_change()

    assert has_element?(view, "#asset-count", "2 monitored")
    assert has_element?(view, "#active-filter-chains-arbitrum", "Network:")
    assert has_element?(view, "#active-filter-chains-arbitrum", "Arbitrum")
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
        "risks" => [""],
        "actions" => ["manual_review"],
        "chains" => [""]
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
        "risks" => [""],
        "actions" => ["liquidation_candidate"],
        "chains" => [""]
      }
    })
    |> render_change()

    assert has_element?(view, "#asset-count", "1 monitored")
    assert has_element?(view, "#asset-row-asset-002", "Liquidation candidate")
    refute has_element?(view, "#asset-row-asset-001")
  end

  test "filters monitored assets by operator review state", %{conn: conn} do
    AssetMonitoringDash.ReviewStore.mark_reviewed("asset-001")
    AssetMonitoringDash.ReviewStore.escalate("asset-003")

    {:ok, view, _html} = live(conn, ~p"/")

    view
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

    assert has_element?(view, "#asset-count", "1 monitored")
    assert has_element?(view, "#asset-row-asset-001", "Reviewed")
    refute has_element?(view, "#asset-row-asset-003")

    view
    |> form("#asset-filters", %{
      "filters" => %{
        "query" => "",
        "risks" => [""],
        "actions" => [""],
        "operator_states" => ["escalated"],
        "chains" => [""]
      }
    })
    |> render_change()

    assert has_element?(view, "#asset-count", "1 monitored")
    assert has_element?(view, "#asset-row-asset-003", "Escalated")
    refute has_element?(view, "#asset-row-asset-001")
  end

  test "combines risk and chain filters", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#asset-filters", %{
      "filters" => %{"query" => "", "risks" => ["Critical"], "chains" => [""]}
    })
    |> render_change()

    view
    |> form("#asset-filters", %{
      "filters" => %{"query" => "", "risks" => ["Critical"], "chains" => ["Arbitrum"]}
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
      "filters" => %{"query" => "mech", "risks" => [""], "chains" => [""]}
    })
    |> render_change()

    assert has_element?(view, "#asset-count", "1 monitored")
    assert has_element?(view, "#active-filter-query-mech", "Search:")
    assert has_element?(view, "#active-filter-query-mech", "mech")
    assert has_element?(view, "#asset-row-asset-010")
    refute has_element?(view, "#asset-row-asset-001")
  end

  test "shows an empty state when asset filters have no matches", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#asset-filters", %{
      "filters" => %{"query" => "missing asset", "risks" => [""], "chains" => [""]}
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
      "filters" => %{"query" => "mech", "risks" => ["Critical"], "chains" => ["Arbitrum"]}
    })
    |> render_change()

    assert has_element?(view, "#asset-count", "1 monitored")
    assert has_element?(view, "#active-filter-chips")

    view
    |> element("#reset-asset-filters")
    |> render_click()

    assert has_element?(view, "#asset-count", "12 monitored")
    refute has_element?(view, "#active-filter-chips")
    assert has_element?(view, "#asset-row-asset-001")
    assert has_element?(view, "#asset-row-asset-010")
  end

  test "removes a single active filter chip", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#asset-filters", %{
      "filters" => %{"query" => "", "risks" => ["Critical"], "chains" => ["Arbitrum"]}
    })
    |> render_change()

    assert has_element?(view, "#asset-count", "1 monitored")
    assert has_element?(view, "#active-filter-risks-critical")
    assert has_element?(view, "#active-filter-chains-arbitrum")

    view
    |> element("#active-filter-chains-arbitrum")
    |> render_click()

    assert has_element?(view, "#asset-count", "2 monitored")
    assert has_element?(view, "#active-filter-risks-critical")
    refute has_element?(view, "#active-filter-chains-arbitrum")
    assert has_element?(view, "#asset-row-asset-002")
    assert has_element?(view, "#asset-row-asset-010")

    view
    |> element("#active-filter-risks-critical")
    |> render_click()

    assert has_element?(view, "#asset-count", "12 monitored")
    refute has_element?(view, "#active-filter-chips")
  end

  test "sorts monitored assets by selected table headers", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert List.first(asset_row_ids(view)) == "asset-row-asset-010"

    view
    |> element("#asset-list-sort-ltv")
    |> render_click()

    assert List.first(asset_row_ids(view)) == "asset-row-asset-011"

    view
    |> element("#asset-list-sort-value")
    |> render_click()

    assert List.first(asset_row_ids(view)) == "asset-row-asset-002"

    view
    |> element("#asset-list-sort-action")
    |> render_click()

    assert List.first(asset_row_ids(view)) == "asset-row-asset-002"
  end

  test "keeps sorting scoped to the filtered assets", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#asset-filters", %{
      "filters" => %{"query" => "", "risks" => [""], "chains" => ["Arbitrum"]}
    })
    |> render_change()

    assert asset_row_ids(view) == ["asset-row-asset-010", "asset-row-asset-005"]

    view
    |> element("#asset-list-sort-value")
    |> render_click()

    assert asset_row_ids(view) == ["asset-row-asset-010", "asset-row-asset-005"]

    view
    |> element("#asset-list-sort-value")
    |> render_click()

    assert asset_row_ids(view) == ["asset-row-asset-005", "asset-row-asset-010"]
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

  defp asset_row_ids(view) do
    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query("#asset-list-rows > div")
    |> LazyHTML.attribute("id")
    |> Enum.filter(&String.starts_with?(&1, "asset-row-"))
  end
end
