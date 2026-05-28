defmodule AssetMonitoringDash.DemoDataTest do
  use ExUnit.Case, async: true

  alias AssetMonitoringDash.DemoData

  test "portfolio snapshot exposes the first dashboard metrics" do
    snapshot = DemoData.portfolio_snapshot()

    assert snapshot.total_collateral_value_usd > 0
    assert snapshot.active_loans > 0
    assert snapshot.weighted_apy_percent > 0
    assert snapshot.risk_score in 0..100
    assert is_binary(snapshot.risk_band)
  end
end
