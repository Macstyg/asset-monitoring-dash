defmodule AssetMonitoringDash.RiskTest do
  use ExUnit.Case, async: true

  alias AssetMonitoringDash.DemoData
  alias AssetMonitoringDash.Risk

  test "calculates collateral health factor with liquidation buffer" do
    asset = DemoData.monitored_assets() |> Enum.find(&(&1.id == "asset-010"))

    assert_decimal_equal(Risk.health_factor(asset), "1.06")
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

    assert %{label: "Conservative LTV", tone: :success, metric: {:percent, ltv_percent}} =
             Enum.find(explanation.reasons, &(&1.id == :ltv_pressure))

    assert_decimal_equal(ltv_percent, "59.7")

    assert %{label: "Healthy buffer", tone: :success, metric: {:decimal, health_factor}} =
             Enum.find(explanation.reasons, &(&1.id == :health_factor))

    assert_decimal_equal(health_factor, "1.42")
  end

  test "explains critical asset risk when health buffer is thin" do
    asset = DemoData.monitored_assets() |> Enum.find(&(&1.id == "asset-010"))

    explanation = Risk.explanation(asset)

    assert explanation.headline == "Position is close to liquidation review."

    assert %{label: "High LTV", tone: :danger, metric: {:percent, ltv_percent}} =
             Enum.find(explanation.reasons, &(&1.id == :ltv_pressure))

    assert_decimal_equal(ltv_percent, "80.1")

    assert %{label: "Thin health buffer", tone: :danger, metric: {:decimal, health_factor}} =
             Enum.find(explanation.reasons, &(&1.id == :health_factor))

    assert_decimal_equal(health_factor, "1.06")
  end

  defp assert_decimal_equal(actual, expected) do
    assert Decimal.equal?(actual, Decimal.new(expected))
  end
end
