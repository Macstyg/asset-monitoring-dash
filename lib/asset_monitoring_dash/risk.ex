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
end
