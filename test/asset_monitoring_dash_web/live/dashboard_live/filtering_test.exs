defmodule AssetMonitoringDashWeb.DashboardLive.FilteringTest do
  use AssetMonitoringDashWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import AssetMonitoringDashWeb.DashboardLiveTestHelpers

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
    assert has_element?(view, "#asset-summary-value", "$136,169")
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

    assert_redirect(view, ~p"/assets/#{asset_id("asset-010")}")
  end

  test "preserves the filtered dashboard URL when navigating to an asset", %{conn: conn} do
    {:ok, view, _html} =
      live(conn, ~p"/?chains=Arbitrum&dir=desc&query=mech&risks=Critical&sort=risk")

    view
    |> element("#asset-row-asset-010")
    |> render_click()

    {redirect_path, _flash} = assert_redirect(view)
    uri = URI.parse(redirect_path)

    assert uri.path == "/assets/#{asset_id("asset-010")}"

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
end
