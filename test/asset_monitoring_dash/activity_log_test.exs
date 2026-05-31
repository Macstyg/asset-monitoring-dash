defmodule AssetMonitoringDash.ActivityLogTest do
  use AssetMonitoringDash.DataCase, async: false

  alias AssetMonitoringDash.ActivityLog
  alias AssetMonitoringDash.Assets
  alias AssetMonitoringDash.ReviewAudit
  alias AssetMonitoringDash.ReviewDecision
  alias AssetMonitoringDash.ReviewState

  test "records scenario events through the activity boundary" do
    asset = asset_fixture()

    ActivityLog.record_price_shock(%{asset | ltv_percent: 67.8}, 12)

    assert [%{id: "event-shock-asset-001"}] =
             ActivityLog.visible_events_for_asset("asset-001")
  end

  test "records review events with normalized audit context" do
    asset = asset_fixture()

    ActivityLog.record_review(
      asset,
      ReviewState.state(:reviewed),
      %{reason: " Oracle checked ", note: " Feed matched "}
    )

    assert [%{review_audit: %ReviewAudit{reason: "Oracle checked", note: "Feed matched"}}] =
             ActivityLog.visible_events_for_asset("asset-001")
  end

  test "records persisted review decisions through the activity boundary" do
    asset = asset_fixture()

    ActivityLog.record_review_decision(asset, ReviewDecision.system_reset(asset.id))

    assert [%{id: "event-review-unreviewed-asset-001", actor: "System"}] =
             ActivityLog.visible_events_for_asset("asset-001")
  end

  defp asset_fixture do
    %{
      id: "asset-001",
      dom_id: "asset-001",
      name: "Aegis Dragon Helm",
      chain: "Polygon",
      ltv_percent: 59.7
    }
    |> Map.put(:id, Assets.resolve_persisted_asset_id("asset-001"))
  end
end
