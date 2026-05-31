defmodule AssetMonitoringDashWeb.DashboardLive.SortingTest do
  use AssetMonitoringDashWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import AssetMonitoringDashWeb.DashboardLiveTestHelpers
  alias AssetMonitoringDash.Assets

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

    review_states = %{
      asset_id("asset-001") => :reviewed,
      asset_id("asset-003") => :escalated
    }

    assert List.first(asset_row_ids(view)) ==
             expected_first_asset_row_id(%{field: :operator, direction: :desc},
               review_states: review_states
             )
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
end
