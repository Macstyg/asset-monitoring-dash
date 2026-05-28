defmodule AssetMonitoringDash.RiskTest do
  use ExUnit.Case, async: true

  alias AssetMonitoringDash.DemoData
  alias AssetMonitoringDash.Risk

  test "calculates collateral health factor with liquidation buffer" do
    asset = DemoData.monitored_assets() |> Enum.find(&(&1.id == "asset-010"))

    assert_in_delta Risk.health_factor(asset), 1.06, 0.01
  end
end
