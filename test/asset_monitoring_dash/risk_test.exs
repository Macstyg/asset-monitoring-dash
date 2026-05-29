defmodule AssetMonitoringDash.RiskTest do
  use ExUnit.Case, async: true

  alias AssetMonitoringDash.DemoData
  alias AssetMonitoringDash.Risk

  test "calculates collateral health factor with liquidation buffer" do
    asset = DemoData.monitored_assets() |> Enum.find(&(&1.id == "asset-010"))

    assert_in_delta Risk.health_factor(asset), 1.06, 0.01
  end

  test "explains elevated asset risk using structured reasons" do
    asset = DemoData.monitored_assets() |> Enum.find(&(&1.id == "asset-001"))

    explanation = Risk.explanation(asset)

    assert explanation.headline == "Collateral buffer needs attention."

    assert Enum.map(explanation.reasons, & &1.id) == [
             :ltv_pressure,
             :health_factor,
             :valuation_gap
           ]

    assert %{label: "Conservative LTV", tone: :success, metric: {:percent, 59.7}} =
             Enum.find(explanation.reasons, &(&1.id == :ltv_pressure))

    assert %{label: "Healthy buffer", tone: :success, metric: {:decimal, health_factor}} =
             Enum.find(explanation.reasons, &(&1.id == :health_factor))

    assert_in_delta health_factor, 1.42, 0.01
  end

  test "explains critical asset risk when health buffer is thin" do
    asset = DemoData.monitored_assets() |> Enum.find(&(&1.id == "asset-010"))

    explanation = Risk.explanation(asset)

    assert explanation.headline == "Position is close to liquidation review."

    assert %{label: "High LTV", tone: :danger, metric: {:percent, 80.1}} =
             Enum.find(explanation.reasons, &(&1.id == :ltv_pressure))

    assert %{label: "Thin health buffer", tone: :danger, metric: {:decimal, health_factor}} =
             Enum.find(explanation.reasons, &(&1.id == :health_factor))

    assert_in_delta health_factor, 1.06, 0.01
  end
end
