defmodule AssetMonitoringDash.Risk do
  @moduledoc """
  Risk calculations for collateral-backed positions.
  """

  @liquidation_buffer Decimal.new("0.85")
  @liquidation_threshold_percent Decimal.new("85")
  @one_hundred Decimal.new("100")

  def health_factor(asset) do
    asset.current_value_usd
    |> decimal()
    |> Decimal.mult(@liquidation_buffer)
    |> Decimal.div(decimal(asset.loan_value_usd))
    |> Decimal.round(2)
  end

  def ltv_percent(asset) do
    asset.loan_value_usd
    |> decimal()
    |> Decimal.div(decimal(asset.current_value_usd))
    |> Decimal.mult(@one_hundred)
    |> Decimal.round(1)
  end

  def risk_score(asset) do
    asset
    |> ltv_percent()
    |> Decimal.div(@liquidation_threshold_percent)
    |> Decimal.mult(@one_hundred)
    |> Decimal.round(0)
    |> Decimal.to_integer()
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

  defp ltv_reason(ltv_percent) do
    cond do
      decimal_gte?(ltv_percent, 75) -> high_ltv_reason(ltv_percent)
      decimal_gte?(ltv_percent, 60) -> rising_ltv_reason(ltv_percent)
      true -> conservative_ltv_reason(ltv_percent)
    end
  end

  defp high_ltv_reason(ltv_percent) do
    %{
      id: :ltv_pressure,
      label: "High LTV",
      metric: {:percent, ltv_percent},
      tone: :danger,
      detail: "Borrowed value is close to the monitored collateral value."
    }
  end

  defp rising_ltv_reason(ltv_percent) do
    %{
      id: :ltv_pressure,
      label: "Rising LTV",
      metric: {:percent, ltv_percent},
      tone: :warning,
      detail: "The loan is using a meaningful share of available collateral."
    }
  end

  defp conservative_ltv_reason(ltv_percent) do
    %{
      id: :ltv_pressure,
      label: "Conservative LTV",
      metric: {:percent, ltv_percent},
      tone: :success,
      detail: "Collateral value is comfortably above borrowed value."
    }
  end

  defp health_reason(health_factor) do
    cond do
      decimal_lt?(health_factor, "1.1") -> thin_health_reason(health_factor)
      decimal_lt?(health_factor, "1.3") -> narrowing_health_reason(health_factor)
      true -> healthy_reason(health_factor)
    end
  end

  defp thin_health_reason(health_factor) do
    %{
      id: :health_factor,
      label: "Thin health buffer",
      metric: {:decimal, health_factor},
      tone: :danger,
      detail: "A small price move could push the position into manual review."
    }
  end

  defp narrowing_health_reason(health_factor) do
    %{
      id: :health_factor,
      label: "Narrowing health",
      metric: {:decimal, health_factor},
      tone: :warning,
      detail: "The liquidation buffer is getting tighter."
    }
  end

  defp healthy_reason(health_factor) do
    %{
      id: :health_factor,
      label: "Healthy buffer",
      metric: {:decimal, health_factor},
      tone: :success,
      detail: "The position has room before review thresholds."
    }
  end

  defp value_reason(%{current_value_usd: current_value_usd, floor_price_usd: floor_price_usd}) do
    case Decimal.compare(decimal(current_value_usd), decimal(floor_price_usd)) do
      :lt -> below_floor_reason(current_value_usd)
      _comparison -> above_floor_reason(current_value_usd)
    end
  end

  defp below_floor_reason(current_value_usd) do
    %{
      id: :valuation_gap,
      label: "Below floor",
      metric: {:usd, current_value_usd},
      tone: :danger,
      detail: "Current valuation is below the reference floor price."
    }
  end

  defp above_floor_reason(current_value_usd) do
    %{
      id: :valuation_gap,
      label: "Above floor",
      metric: {:usd, current_value_usd},
      tone: :neutral,
      detail: "Current valuation remains above the reference floor price."
    }
  end

  defp decimal(%Decimal{} = value), do: value
  defp decimal(value) when is_integer(value), do: Decimal.new(value)

  defp decimal(value) when is_float(value) do
    value
    |> Float.to_string()
    |> Decimal.new()
  end

  defp decimal(value) when is_binary(value), do: Decimal.new(value)

  defp decimal_gte?(value, threshold),
    do: Decimal.compare(decimal(value), decimal(threshold)) in [:gt, :eq]

  defp decimal_lt?(value, threshold),
    do: Decimal.compare(decimal(value), decimal(threshold)) == :lt
end
