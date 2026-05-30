defmodule AssetMonitoringDashWeb.DashboardLiveTest do
  use AssetMonitoringDashWeb.ConnCase

  import Phoenix.LiveViewTest

  alias AssetMonitoringDash.Assets
  alias AssetMonitoringDash.EventStore
  alias AssetMonitoringDash.ReviewState

  test "renders the asset risk cockpit as a full-width monitor", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#dashboard-shell")
    assert has_element?(view, "#metric-strip")
    assert has_element?(view, "#collateral-value-card")
    assert has_element?(view, "#collateral-value-card", "$3.5M")
    assert has_element?(view, "#active-loans-card")
    assert has_element?(view, "#weighted-apy-card")
    assert has_element?(view, "#risk-score-card")
    assert has_element?(view, "#risk-score-card", "54/100")
    assert has_element?(view, "#risk-score-card", "moderate pressure")
    assert has_element?(view, "#asset-monitor")
    assert has_element?(view, "#theme-toggle")
    assert has_element?(view, "#asset-count", "600 monitored")
    assert has_element?(view, "#asset-loaded-count", "Showing 1-50 of 600")
    assert has_element?(view, "#asset-load-hint", "Scroll to load more")
    assert has_element?(view, "#asset-list")
    assert has_element?(view, ~s(#asset-list-rows[phx-hook="ScrollableLoadMore"]))
    assert has_element?(view, ~s(#asset-list-rows[data-load-more-event="load_more_assets"]))
    assert has_element?(view, ~s(#asset-list-rows[data-load-more-target="asset-table-loading"]))
    assert has_element?(view, ~s(#asset-list-rows[class*="overflow-y-auto"]))
    assert has_element?(view, "#asset-table-range", "Showing 1-50 of 600")
    assert has_element?(view, "#asset-table-loading", "Loading more...")
    refute has_element?(view, "#asset-table-end")
    assert has_element?(view, "#asset-summary")
    assert has_element?(view, "#asset-summary-visible-count", "600")
    assert has_element?(view, "#asset-summary-value", "$3,474,056")
    assert has_element?(view, "#asset-summary-at-risk", "165")
    assert has_element?(view, "#asset-summary-highest-ltv", "80.1%")
    assert has_element?(view, "#asset-filters")
    assert has_element?(view, "#asset-view-state", "Default view")
    assert has_element?(view, "#copy-asset-view-link", "Copy view link")
    assert has_element?(view, "#filters_query")
    assert has_element?(view, "#filters_risks_filter")
    assert has_element?(view, "#filters_actions_filter")
    assert has_element?(view, "#filters_operator_states_filter")
    assert has_element?(view, "#filters_chains_filter")
    assert has_element?(view, "#filters_chains_Polygon")
    assert has_element?(view, "#filters_risks_Critical")
    assert has_element?(view, "#reset-asset-filters")
    assert has_element?(view, "#asset-list-sort-asset")
    assert has_element?(view, "#asset-list-sort-chain")
    assert has_element?(view, "#asset-list-sort-floor")
    assert has_element?(view, "#asset-list-sort-value")
    assert has_element?(view, "#asset-list-sort-ltv")
    assert has_element?(view, "#asset-list-sort-risk")
    assert has_element?(view, "#asset-list-sort-operator")
    assert has_element?(view, "#asset-list-sort-action")
    assert has_element?(view, "#asset-mobile-sort-asset")
    assert has_element?(view, "#asset-mobile-sort-chain")
    assert has_element?(view, "#asset-mobile-sort-floor")
    assert has_element?(view, "#asset-mobile-sort-value")
    assert has_element?(view, "#asset-mobile-sort-ltv")
    assert has_element?(view, "#asset-mobile-sort-risk")
    assert has_element?(view, "#asset-mobile-sort-operator")
    assert has_element?(view, "#asset-mobile-sort-action")
    refute has_element?(view, "#active-filter-chips")
    refute has_element?(view, "#active-scenario-banner")
    assert length(asset_row_ids(view)) == 50
    assert has_element?(view, "#asset-row-asset-010")
    assert has_element?(view, ~s(#asset-row-asset-010 img[src="/images/assets/mech-core.svg"]))
    assert has_element?(view, ~s(#asset-row-asset-010 [aria-label="Arbitrum chain"]))
    assert has_element?(view, "#asset-row-asset-010", "Manual review")
    refute has_element?(view, "#asset-row-asset-001")
    refute has_element?(view, "#asset-inspection")
    assert has_element?(view, "#event-feed")
    assert has_element?(view, "#event-count", "5 events")
    assert has_element?(view, "#event-feed-state", "streaming")
    assert has_element?(view, "#event-filters")
    assert has_element?(view, "#event_filters_sources_filter")
    assert has_element?(view, "#event_filters_sources_system")
    assert has_element?(view, "#event_filters_sources_operator")
    assert has_element?(view, "#event_filters_sources_scenario")
    refute has_element?(view, "#active-event-filter-chips")
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

  test "loads asset filters and sort from URL params", %{conn: conn} do
    {:ok, view, _html} =
      live(conn, ~p"/?query=mech&chains=Arbitrum&risks=Critical&sort=value&dir=asc")

    filters = %{
      Assets.default_filters()
      | query: "mech",
        chains: ["Arbitrum"],
        risks: ["Critical"]
    }

    assert has_element?(view, "#asset-count", "13 monitored")
    assert has_element?(view, "#asset-loaded-count", "Showing 1-13 of 13")
    assert has_element?(view, "#asset-view-state", "Filtered view")
    assert has_element?(view, "#active-filter-query-mech", "mech")
    assert has_element?(view, "#active-filter-chains-arbitrum", "Arbitrum")
    assert has_element?(view, "#active-filter-risks-critical", "Critical")

    assert List.first(asset_row_ids(view)) ==
             expected_first_asset_row_id(%{field: :value, direction: :asc}, filters: filters)
  end

  test "patches the URL when asset filters change", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#asset-filters", %{
      "filters" => %{"query" => "mech", "risks" => ["Critical"], "chains" => ["Arbitrum"]}
    })
    |> render_change()

    params = patch_query_params(assert_patch(view))

    assert params["query"] == "mech"
    assert params["risks"] == "Critical"
    assert params["chains"] == "Arbitrum"
    refute Map.has_key?(params, "sort")
    assert has_element?(view, "#asset-count", "13 monitored")
  end

  test "patches the URL when asset sorting changes and preserves filters", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/?query=mech&chains=Arbitrum")

    view
    |> element("#asset-list-sort-value")
    |> render_click()

    params = patch_query_params(assert_patch(view))

    assert params["query"] == "mech"
    assert params["chains"] == "Arbitrum"
    assert params["sort"] == "value"
    assert params["dir"] == "desc"
  end

  test "resetting asset filters clears filter and sort URL params", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/?query=mech&chains=Arbitrum&sort=value&dir=asc")

    view
    |> element("#reset-asset-filters")
    |> render_click()

    assert assert_patch(view) == "/"
    assert has_element?(view, "#asset-count", "600 monitored")
    refute has_element?(view, "#active-filter-chips")
  end

  test "filters monitored assets by risk band", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#asset-filters", %{
      "filters" => %{"query" => "", "risks" => ["Critical"], "chains" => [""]}
    })
    |> render_change()

    assert has_element?(view, "#asset-count", "14 monitored")
    assert has_element?(view, "#asset-summary-visible-count", "14")
    assert has_element?(view, "#asset-summary-value", "$136,168")
    assert has_element?(view, "#asset-summary-at-risk", "14")
    assert has_element?(view, "#asset-summary-highest-ltv", "80.1%")
    assert has_element?(view, "#asset-loaded-count", "Showing 1-14 of 14")
    assert has_element?(view, "#asset-table-range", "Showing 1-14 of 14")
    assert has_element?(view, "#asset-table-end", "All matching assets loaded")
    refute has_element?(view, "#asset-load-hint")
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

    assert has_element?(view, "#asset-count", "600 monitored")
    assert has_element?(view, "#asset-loaded-count", "Showing 1-50 of 600")
    refute has_element?(view, "#active-filter-chips")
    assert has_element?(view, "#asset-row-asset-010")
  end

  test "navigates to the selected asset detail page from a row", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> element("#asset-row-asset-010")
    |> render_click()

    assert_redirect(view, ~p"/assets/asset-010")
  end

  test "preserves the filtered dashboard URL when navigating to an asset", %{conn: conn} do
    {:ok, view, _html} =
      live(conn, ~p"/?chains=Arbitrum&dir=desc&query=mech&risks=Critical&sort=risk")

    view
    |> element("#asset-row-asset-010")
    |> render_click()

    {redirect_path, _flash} = assert_redirect(view)
    uri = URI.parse(redirect_path)

    assert uri.path == "/assets/asset-010"

    assert uri.query
           |> URI.decode_query()
           |> Map.fetch!("return_to")
           |> URI.decode()
           |> URI.parse()
           |> Map.take([:path, :query]) == %{
             path: "/",
             query: "chains=Arbitrum&dir=desc&query=mech&risks=Critical&sort=risk"
           }
  end

  test "filters monitored assets by chain", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#asset-filters", %{
      "filters" => %{"query" => "", "risks" => [""], "chains" => ["Arbitrum"]}
    })
    |> render_change()

    assert has_element?(view, "#asset-count", "100 monitored")
    assert has_element?(view, "#asset-loaded-count", "Showing 1-50 of 100")
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

    assert has_element?(view, "#asset-count", "336 monitored")
    assert has_element?(view, "#asset-row-asset-010", "Manual review")
    assert has_element?(view, "#asset-loaded-count", "Showing 1-50 of 336")
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

    assert has_element?(view, "#asset-count", "4 monitored")
    assert has_element?(view, "#asset-loaded-count", "Showing 1-4 of 4")
    assert has_element?(view, "#asset-table-end", "All matching assets loaded")
    assert has_element?(view, "#asset-row-asset-010-variant-010", "Liquidation candidate")
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

    assert has_element?(view, "#asset-count", "13 monitored")
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

    assert has_element?(view, "#asset-count", "50 monitored")
    assert has_element?(view, "#asset-loaded-count", "Showing 1-50 of 50")
    assert has_element?(view, "#asset-table-end", "All matching assets loaded")
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
    assert has_element?(view, "#asset-loaded-count", "Showing 0 of 0")
    assert has_element?(view, "#asset-table-range", "Showing 0 of 0")
    refute has_element?(view, "#asset-table-end")
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

    assert has_element?(view, "#asset-count", "13 monitored")
    assert has_element?(view, "#active-filter-chips")

    view
    |> element("#reset-asset-filters")
    |> render_click()

    assert has_element?(view, "#asset-count", "600 monitored")
    refute has_element?(view, "#active-filter-chips")
    assert has_element?(view, "#asset-row-asset-010")
  end

  test "removes a single active filter chip", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#asset-filters", %{
      "filters" => %{"query" => "", "risks" => ["Critical"], "chains" => ["Arbitrum"]}
    })
    |> render_change()

    assert has_element?(view, "#asset-count", "13 monitored")
    assert has_element?(view, "#active-filter-risks-critical")
    assert has_element?(view, "#active-filter-chains-arbitrum")

    view
    |> element("#active-filter-chains-arbitrum")
    |> render_click()

    assert has_element?(view, "#asset-count", "14 monitored")
    assert has_element?(view, "#active-filter-risks-critical")
    refute has_element?(view, "#active-filter-chains-arbitrum")
    assert has_element?(view, "#asset-row-asset-002")
    assert has_element?(view, "#asset-row-asset-010")

    view
    |> element("#active-filter-risks-critical")
    |> render_click()

    assert has_element?(view, "#asset-count", "600 monitored")
    refute has_element?(view, "#active-filter-chips")
  end

  test "loads additional assets when the viewport reaches the table bottom", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert length(asset_row_ids(view)) == 50
    assert has_element?(view, "#asset-loaded-count", "Showing 1-50 of 600")

    view
    |> element("#asset-list-rows")
    |> render_hook("load_more_assets")

    assert length(asset_row_ids(view)) == 100
    assert has_element?(view, "#asset-loaded-count", "Showing 1-100 of 600")
    assert has_element?(view, "#asset-table-range", "Showing 1-100 of 600")

    view
    |> element("#asset-list-rows")
    |> render_hook("load_more_assets")

    view
    |> element("#asset-list-rows")
    |> render_hook("load_more_assets")

    assert length(asset_row_ids(view)) in 140..150
    assert has_element?(view, "#asset-loaded-count", "Showing 1-200 of 600")
    assert has_element?(view, "#asset-table-range", "Showing 1-200 of 600")
  end

  test "sorts monitored assets by selected table headers", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert List.first(asset_row_ids(view)) ==
             expected_first_asset_row_id(%{field: :ltv, direction: :desc})

    view
    |> element("#asset-list-sort-ltv")
    |> render_click()

    assert List.first(asset_row_ids(view)) ==
             expected_first_asset_row_id(%{field: :ltv, direction: :asc})

    view
    |> element("#asset-list-sort-asset")
    |> render_click()

    assert List.first(asset_row_ids(view)) ==
             expected_first_asset_row_id(%{field: :asset, direction: :asc})

    view
    |> element("#asset-list-sort-chain")
    |> render_click()

    assert List.first(asset_row_ids(view)) ==
             expected_first_asset_row_id(%{field: :chain, direction: :asc})

    view
    |> element("#asset-list-sort-floor")
    |> render_click()

    assert List.first(asset_row_ids(view)) ==
             expected_first_asset_row_id(%{field: :floor, direction: :desc})

    view
    |> element("#asset-list-sort-value")
    |> render_click()

    assert List.first(asset_row_ids(view)) ==
             expected_first_asset_row_id(%{field: :value, direction: :desc})

    view
    |> element("#asset-list-sort-risk")
    |> render_click()

    assert List.first(asset_row_ids(view)) ==
             expected_first_asset_row_id(%{field: :risk, direction: :desc})

    view
    |> element("#asset-list-sort-action")
    |> render_click()

    assert List.first(asset_row_ids(view)) ==
             expected_first_asset_row_id(%{field: :action, direction: :desc})
  end

  test "sorts monitored assets by operator state priority", %{conn: conn} do
    AssetMonitoringDash.ReviewStore.mark_reviewed("asset-001")
    AssetMonitoringDash.ReviewStore.escalate("asset-003")

    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> element("#asset-list-sort-operator")
    |> render_click()

    review_states = %{"asset-001" => :reviewed, "asset-003" => :escalated}

    assert List.first(asset_row_ids(view)) ==
             expected_first_asset_row_id(%{field: :operator, direction: :desc},
               review_states: review_states
             )
  end

  test "shows and resets active asset scenarios", %{conn: conn} do
    AssetMonitoringDash.AssetScenarioStore.apply_price_shock("asset-001")
    AssetMonitoringDash.ReviewStore.mark_reviewed("asset-001")

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#active-scenario-banner")
    assert has_element?(view, "#active-scenario-count", "1 active scenario")
    assert has_element?(view, "#reset-asset-scenarios")

    view
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

    assert has_element?(view, "#asset-count", "50 monitored")
    assert has_element?(view, "#asset-row-asset-001", "$4,277")
    assert has_element?(view, "#asset-row-asset-001", "67.8%")
    assert has_element?(view, "#asset-scenario-asset-001", "Price shock")
    assert has_element?(view, "#asset-row-asset-001", "Reviewed")

    view
    |> element("#reset-asset-scenarios")
    |> render_click()

    refute has_element?(view, "#active-scenario-banner")
    refute has_element?(view, "#asset-scenario-asset-001")
    assert has_element?(view, "#event-row-event-reset-asset-001", "Scenario reset")
    assert has_element?(view, "#asset-row-asset-001", "$4,860")
    assert has_element?(view, "#asset-row-asset-001", "59.7%")
    assert has_element?(view, "#asset-row-asset-001", "Unreviewed")
  end

  test "keeps sorting scoped to the filtered assets", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")
    filters = %{Assets.default_filters() | chains: ["Arbitrum"]}

    view
    |> form("#asset-filters", %{
      "filters" => %{"query" => "", "risks" => [""], "chains" => ["Arbitrum"]}
    })
    |> render_change()

    assert asset_row_ids(view) ==
             expected_asset_row_ids(%{field: :ltv, direction: :desc}, filters: filters)

    view
    |> element("#asset-list-sort-value")
    |> render_click()

    assert asset_row_ids(view) ==
             expected_asset_row_ids(%{field: :value, direction: :desc}, filters: filters)

    view
    |> element("#asset-list-sort-value")
    |> render_click()

    assert asset_row_ids(view) ==
             expected_asset_row_ids(%{field: :value, direction: :asc}, filters: filters)
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

  test "filters event feed by source kind", %{conn: conn} do
    asset = asset_fixture("asset-001")

    EventStore.push_price_shock_event(%{asset | ltv_percent: 67.8}, 12)
    EventStore.push_review_event(asset, ReviewState.state(:reviewed))

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#event-count", "6 events")
    assert has_element?(view, "#event-row-event-review-reviewed-asset-001")
    assert has_element?(view, "#event-row-event-shock-asset-001")

    view
    |> form("#event-filters", %{
      "event_filters" => %{"sources" => ["scenario"], "source_option_query" => ""}
    })
    |> render_change()

    assert has_element?(view, "#event-count", "1 events")
    assert has_element?(view, "#active-event-filter-chips")
    assert has_element?(view, "#active-filter-event-sources-scenario", "Scenario")
    assert has_element?(view, "#event-row-event-shock-asset-001", "Price shock applied")
    refute has_element?(view, "#event-row-event-review-reviewed-asset-001")
    refute has_element?(view, "#event-row-event-001")

    view
    |> form("#event-filters", %{
      "event_filters" => %{"sources" => ["operator"], "source_option_query" => ""}
    })
    |> render_change()

    assert has_element?(view, "#event-count", "1 events")
    assert has_element?(view, "#event-row-event-review-reviewed-asset-001", "Position reviewed")
    refute has_element?(view, "#event-row-event-shock-asset-001")

    view
    |> form("#event-filters", %{
      "event_filters" => %{"sources" => ["system"], "source_option_query" => ""}
    })
    |> render_change()

    assert has_element?(view, "#event-count", "4 events")
    assert has_element?(view, "#event-row-event-001")
    refute has_element?(view, "#event-row-event-review-reviewed-asset-001")
    refute has_element?(view, "#event-row-event-shock-asset-001")

    view
    |> form("#event-filters", %{
      "event_filters" => %{"sources" => [""], "source_option_query" => ""}
    })
    |> render_change()

    assert has_element?(view, "#event-count", "6 events")
    assert has_element?(view, "#event-row-event-review-reviewed-asset-001")
    assert has_element?(view, "#event-row-event-shock-asset-001")
  end

  test "combines multiple event source filters", %{conn: conn} do
    asset = asset_fixture("asset-001")

    EventStore.push_price_shock_event(%{asset | ltv_percent: 67.8}, 12)
    EventStore.push_review_event(asset, ReviewState.state(:reviewed))

    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#event-filters", %{
      "event_filters" => %{"sources" => ["scenario", "operator"], "source_option_query" => ""}
    })
    |> render_change()

    assert has_element?(view, "#event-count", "2 events")
    assert has_element?(view, "#event-row-event-shock-asset-001")
    assert has_element?(view, "#event-row-event-review-reviewed-asset-001")
    assert has_element?(view, "#active-filter-event-sources-scenario")
    assert has_element?(view, "#active-filter-event-sources-operator")
    refute has_element?(view, "#event-row-event-001")

    view
    |> element("#active-filter-event-sources-scenario")
    |> render_click()

    assert has_element?(view, "#event-count", "1 events")
    assert has_element?(view, "#event-row-event-review-reviewed-asset-001")
    refute has_element?(view, "#event-row-event-shock-asset-001")
    refute has_element?(view, "#active-filter-event-sources-scenario")
  end

  test "event source filters can show an empty feed slice", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#event-filters", %{
      "event_filters" => %{"sources" => ["scenario"], "source_option_query" => ""}
    })
    |> render_change()

    assert has_element?(view, "#event-count", "0 events")
    assert has_element?(view, "#event-list-empty", "No events for this filter.")
    refute has_element?(view, "#event-row-event-001")
  end

  test "active event source filters are not displaced by hidden system ticks", %{conn: conn} do
    asset = asset_fixture("asset-001")

    EventStore.push_price_shock_event(%{asset | ltv_percent: 67.8}, 12)

    {:ok, view, _html} = live(conn, ~p"/")

    view
    |> form("#event-filters", %{
      "event_filters" => %{"sources" => ["scenario"], "source_option_query" => ""}
    })
    |> render_change()

    assert has_element?(view, "#event-count", "1 events")
    assert has_element?(view, "#event-row-event-shock-asset-001")

    for _index <- 1..3 do
      view
      |> element("#push-demo-event")
      |> render_click()
    end

    assert has_element?(view, "#event-count", "1 events")
    assert has_element?(view, "#event-row-event-shock-asset-001")
    refute has_element?(view, "#event-row-event-live-3")
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

  defp patch_query_params(path) do
    path
    |> URI.parse()
    |> Map.fetch!(:query)
    |> case do
      nil -> %{}
      query -> URI.decode_query(query)
    end
  end

  defp expected_first_asset_row_id(sort, opts \\ []) do
    sort
    |> expected_asset_row_ids(opts)
    |> List.first()
  end

  defp expected_asset_row_ids(sort, opts) do
    filters = Keyword.get(opts, :filters, Assets.default_filters())
    review_states = Keyword.get(opts, :review_states, %{})
    shocked_asset_ids = Keyword.get(opts, :shocked_asset_ids, MapSet.new())
    limit = Keyword.get(opts, :limit, 50)

    %{
      filters: filters,
      sort: sort,
      cursor: nil,
      limit: limit,
      review_states: review_states,
      shocked_asset_ids: shocked_asset_ids
    }
    |> Assets.list_assets_page()
    |> Map.fetch!(:entries)
    |> Enum.map(&"asset-row-#{&1.id}")
  end

  defp asset_fixture(asset_id) do
    Assets.list_assets()
    |> Enum.find(&(&1.id == asset_id))
  end
end
