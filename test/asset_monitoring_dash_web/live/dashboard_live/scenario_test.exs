defmodule AssetMonitoringDashWeb.DashboardLive.ScenarioTest do
  use AssetMonitoringDashWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias AssetMonitoringDash.ActivityLog
  alias AssetMonitoringDash.Assets
  alias AssetMonitoringDash.AssetScenarioStore
  alias AssetMonitoringDash.ReviewStore
  alias AssetMonitoringDash.Simulator

  test "shows and resets active asset scenarios", %{conn: conn} do
    AssetMonitoringDash.AssetScenarioStore.apply_price_shock("asset-001")
    AssetMonitoringDash.ReviewStore.mark_reviewed("asset-001")

    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#active-scenario-banner")
    assert has_element?(view, "#active-scenario-count", "1 active scenario")
    assert has_element?(view, "#reset-asset-scenarios")
    assert has_element?(view, "#demo-story-state", "1 scenario active")
    assert has_element?(view, "#demo-inspect-asset", "Aegis Dragon Helm")

    assert has_element?(
             view,
             ~s(#demo-inspect-asset[href="/assets/#{asset_id("asset-001")}?demo=story"])
           )

    refute has_element?(view, "#demo-inspect-asset-placeholder")

    view
    |> element("#demo-open-analytics")
    |> render_click()

    assert has_element?(view, "#demo-step-dashboard", "observed")

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
    assert has_element?(view, "#asset-scenario-asset-001", "Scenario: Price")
    assert has_element?(view, "#asset-row-asset-001", "Reviewed")

    view
    |> element("#reset-asset-scenarios")
    |> render_click()

    refute has_element?(view, "#active-scenario-banner")
    refute has_element?(view, "#asset-scenario-asset-001")
    refute has_element?(view, "#demo-inspect-asset")
    assert has_element?(view, "#demo-story-state", "Ready")
    assert has_element?(view, "#demo-inspect-asset-placeholder", "Waiting for scenario")
    assert has_element?(view, "#event-row-event-reset-asset-001", "Scenario reset")
    assert has_element?(view, "#asset-row-asset-001", "$4,860")
    assert has_element?(view, "#asset-row-asset-001", "59.7%")
    assert has_element?(view, "#asset-row-asset-001", "Unreviewed")
  end

  test "refreshes scenario state from simulator broadcasts", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    ReviewStore.mark_reviewed("asset-001")

    shocked_asset_ids = AssetScenarioStore.apply_price_shock("asset-001")
    asset = Assets.get_persisted_asset_with_scenarios("asset-001", shocked_asset_ids)

    ActivityLog.record_price_shock(asset, AssetScenarioStore.price_shock_drop_percent())

    review_reset = ReviewStore.reset_after_scenario(asset.id)
    ActivityLog.record_review_decision(asset, review_reset.decision)

    send(view.pid, {
      Simulator,
      :scenario_applied,
      %{
        asset: asset,
        event_history: ActivityLog.visible_events(),
        next_event_index: 0,
        review_states: review_reset.states,
        shocked_asset_ids: shocked_asset_ids
      }
    })

    assert has_element?(view, "#active-scenario-banner")
    assert has_element?(view, "#active-scenario-count", "1 active scenario")
    assert has_element?(view, "#asset-scenario-asset-001", "Scenario: Price")
    assert has_element?(view, "#asset-row-asset-001", "Unreviewed")
    assert has_element?(view, "#event-row-event-review-unreviewed-asset-001")
    assert has_element?(view, "#event-row-event-shock-asset-001", "Price shock applied")
  end

  test "resets mutable demo runtime from the simulator panel", %{conn: conn} do
    AssetScenarioStore.apply_price_shock("asset-001")
    ReviewStore.mark_reviewed("asset-001")

    asset =
      Assets.get_persisted_asset_with_scenarios(
        "asset-001",
        AssetScenarioStore.shocked_asset_ids()
      )

    ActivityLog.record_price_shock(asset, AssetScenarioStore.price_shock_drop_percent())

    {:ok, view, _html} = live(conn, ~p"/")

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

    assert has_element?(view, "#active-scenario-banner")
    assert has_element?(view, "#asset-row-asset-001", "$4,277")
    assert has_element?(view, "#asset-row-asset-001", "Reviewed")
    assert has_element?(view, "#event-row-event-shock-asset-001")

    view
    |> element("#simulator-reset-runtime")
    |> render_click()

    refute has_element?(view, "#active-scenario-banner")
    refute has_element?(view, "#asset-scenario-asset-001")
    refute has_element?(view, "#event-row-event-shock-asset-001")
    refute has_element?(view, "#event-row-event-review-reviewed-asset-001")
    assert has_element?(view, "#asset-row-asset-001", "$4,860")
    assert has_element?(view, "#asset-row-asset-001", "59.7%")
    assert has_element?(view, "#asset-row-asset-001", "Unreviewed")
    assert has_element?(view, "#event-count", "5 events")
    assert has_element?(view, "#event-row-event-001", "Collateral deposited")
    assert has_element?(view, "#simulator-status")
  end
end
