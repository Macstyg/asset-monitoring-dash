defmodule AssetMonitoringDashWeb.AssetLive.ScenarioTest do
  use AssetMonitoringDashWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import AssetMonitoringDashWeb.AssetLiveTestHelpers

  alias AssetMonitoringDash.ActivityLog
  alias AssetMonitoringDash.Assets
  alias AssetMonitoringDash.AssetScenarioStore
  alias AssetMonitoringDash.Simulator

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

  test "refreshes inspected asset when simulator applies a matching scenario", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/assets/asset-001")

    assert has_element?(view, "#asset-inspection", "$4,860")
    assert has_element?(view, "#asset-ltv-trend-latest", "59.7%")
    assert has_element?(view, "#reset-asset-scenario[disabled]")

    shocked_asset_ids = AssetScenarioStore.apply_price_shock("asset-001")
    asset = Assets.get_persisted_asset_with_scenarios("asset-001", shocked_asset_ids)

    event_history =
      ActivityLog.record_price_shock(asset, AssetScenarioStore.price_shock_drop_percent())

    send(view.pid, {
      Simulator,
      :scenario_applied,
      %{
        asset: asset,
        event_history: event_history,
        next_event_index: 0,
        shocked_asset_ids: shocked_asset_ids
      }
    })

    assert has_element?(view, "#asset-inspection", "$4,277")
    assert has_element?(view, "#asset-ltv-trend-latest", "67.8%")
    assert has_element?(view, "#apply-price-shock[disabled]", "Shock applied")

    view
    |> element("#asset-focus-activity")
    |> render_click()

    assert has_element?(view, "#asset-event-count", "1 events")
    assert has_element?(view, "#asset-event-row-event-shock-asset-001", "Price shock applied")
  end

  test "ignores simulator scenarios for other inspected assets", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/assets/asset-001")

    shocked_asset_ids = AssetScenarioStore.apply_price_shock("asset-002")
    asset = Assets.get_persisted_asset_with_scenarios("asset-002", shocked_asset_ids)

    event_history =
      ActivityLog.record_price_shock(asset, AssetScenarioStore.price_shock_drop_percent())

    send(view.pid, {
      Simulator,
      :scenario_applied,
      %{
        asset: asset,
        event_history: event_history,
        next_event_index: 0,
        shocked_asset_ids: shocked_asset_ids
      }
    })

    assert has_element?(view, "#asset-inspection", "$4,860")
    assert has_element?(view, "#asset-ltv-trend-latest", "59.7%")
    assert has_element?(view, "#reset-asset-scenario[disabled]")

    view
    |> element("#asset-focus-activity")
    |> render_click()

    assert has_element?(view, "#asset-event-count", "0 events")
    refute has_element?(view, "#asset-event-row-event-shock-asset-002")
  end
end
