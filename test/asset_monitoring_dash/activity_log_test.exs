defmodule AssetMonitoringDash.ActivityLogTest do
  use ExUnit.Case, async: false

  alias AssetMonitoringDash.ActivityLog
  alias AssetMonitoringDash.EventStore
  alias AssetMonitoringDash.ReviewAudit
  alias AssetMonitoringDash.ReviewState

  setup do
    EventStore.reset_all()

    :ok
  end

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

  defp asset_fixture do
    %{
      id: "asset-001",
      name: "Aegis Dragon Helm",
      chain: "Polygon",
      ltv_percent: 59.7
    }
  end
end
