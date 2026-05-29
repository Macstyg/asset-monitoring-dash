defmodule AssetMonitoringDash.Risk do
  @moduledoc """
  Risk calculations for collateral-backed positions.
  """

  @liquidation_buffer 0.85
  @liquidation_threshold_percent 85

  def health_factor(asset) do
    asset.current_value_usd * @liquidation_buffer / asset.loan_value_usd
  end

  def ltv_percent(asset) do
    asset.loan_value_usd / asset.current_value_usd * 100
  end

  def risk_score(asset) do
    asset
    |> ltv_percent()
    |> Kernel./(@liquidation_threshold_percent)
    |> Kernel.*(100)
    |> round()
    |> min(100)
    |> max(0)
  end

  def risk_band(score) when score >= 85, do: "Critical"
  def risk_band(score) when score >= 65, do: "Elevated"
  def risk_band(score) when score >= 40, do: "Moderate"
  def risk_band(_score), do: "Low"

  def explanation(asset) do
    %{
      headline: headline(asset.risk_band),
      reasons: [
        ltv_reason(asset.ltv_percent),
        health_reason(health_factor(asset)),
        value_reason(asset)
      ]
    }
  end

  defp headline("Critical"), do: "Position is close to liquidation review."
  defp headline("Elevated"), do: "Collateral buffer needs attention."
  defp headline("Moderate"), do: "Position is stable but worth watching."
  defp headline("Low"), do: "Position has a comfortable collateral buffer."
  defp headline(_risk_band), do: "Position risk is being monitored."

  defp ltv_reason(ltv_percent) when ltv_percent >= 75 do
    %{
      id: :ltv_pressure,
      label: "High LTV",
      metric: {:percent, ltv_percent},
      tone: :danger,
      detail: "Borrowed value is close to the monitored collateral value."
    }
  end

  defp ltv_reason(ltv_percent) when ltv_percent >= 60 do
    %{
      id: :ltv_pressure,
      label: "Rising LTV",
      metric: {:percent, ltv_percent},
      tone: :warning,
      detail: "The loan is using a meaningful share of available collateral."
    }
  end

  defp ltv_reason(ltv_percent) do
    %{
      id: :ltv_pressure,
      label: "Conservative LTV",
      metric: {:percent, ltv_percent},
      tone: :success,
      detail: "Collateral value is comfortably above borrowed value."
    }
  end

  defp health_reason(health_factor) when health_factor < 1.1 do
    %{
      id: :health_factor,
      label: "Thin health buffer",
      metric: {:decimal, health_factor},
      tone: :danger,
      detail: "A small price move could push the position into manual review."
    }
  end

  defp health_reason(health_factor) when health_factor < 1.3 do
    %{
      id: :health_factor,
      label: "Narrowing health",
      metric: {:decimal, health_factor},
      tone: :warning,
      detail: "The liquidation buffer is getting tighter."
    }
  end

  defp health_reason(health_factor) do
    %{
      id: :health_factor,
      label: "Healthy buffer",
      metric: {:decimal, health_factor},
      tone: :success,
      detail: "The position has room before review thresholds."
    }
  end

  defp value_reason(%{current_value_usd: current_value_usd, floor_price_usd: floor_price_usd})
       when current_value_usd < floor_price_usd do
    %{
      id: :valuation_gap,
      label: "Below floor",
      metric: {:usd, current_value_usd},
      tone: :danger,
      detail: "Current valuation is below the reference floor price."
    }
  end

  defp value_reason(%{current_value_usd: current_value_usd}) do
    %{
      id: :valuation_gap,
      label: "Above floor",
      metric: {:usd, current_value_usd},
      tone: :neutral,
      detail: "Current valuation remains above the reference floor price."
    }
  end
end
