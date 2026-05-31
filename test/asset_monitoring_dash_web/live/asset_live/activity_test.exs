defmodule AssetMonitoringDashWeb.AssetLive.ActivityTest do
  use AssetMonitoringDashWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import AssetMonitoringDashWeb.AssetLiveTestHelpers
  alias AssetMonitoringDash.ActivityLog
  alias AssetMonitoringDash.ReviewState

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
end
