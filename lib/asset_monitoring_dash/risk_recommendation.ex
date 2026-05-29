defmodule AssetMonitoringDash.RiskRecommendation do
  @moduledoc """
  Read-only system recommendation for monitored collateral positions.

  This is derived from current asset risk data. It should not be changed by
  operator workflow actions such as marking a position reviewed.
  """

  alias AssetMonitoringDash.Risk

  @recommendations %{
    clear: %{
      id: :clear,
      label: "Clear",
      detail: "System sees no immediate action while collateral remains healthy.",
      tone: :success
    },
    watch: %{
      id: :watch,
      label: "Watch",
      detail: "System recommends monitoring price and oracle movement.",
      tone: :info
    },
    manual_review: %{
      id: :manual_review,
      label: "Manual review",
      detail: "System recommends analyst review before trusting automation.",
      tone: :warning
    },
    liquidation_candidate: %{
      id: :liquidation_candidate,
      label: "Liquidation candidate",
      detail: "System sees a thin collateral buffer that may need escalation.",
      tone: :danger
    }
  }

  def recommendation_for(asset) do
    asset
    |> recommendation_id()
    |> recommendation()
  end

  def recommendation(:clear), do: @recommendations.clear
  def recommendation(:watch), do: @recommendations.watch
  def recommendation(:manual_review), do: @recommendations.manual_review
  def recommendation(:liquidation_candidate), do: @recommendations.liquidation_candidate

  defp recommendation_id(%{oracle_status: "Stale", risk_band: risk_band})
       when risk_band in ["Moderate", "Elevated", "Critical"],
       do: :manual_review

  defp recommendation_id(%{oracle_status: "Stale"}), do: :watch

  defp recommendation_id(%{oracle_status: "Delayed", risk_band: "Critical"}),
    do: :manual_review

  defp recommendation_id(%{liquidity_status: "Illiquid", risk_band: risk_band})
       when risk_band in ["Moderate", "Elevated", "Critical"],
       do: :manual_review

  defp recommendation_id(%{liquidity_status: "Illiquid"}), do: :watch

  defp recommendation_id(%{risk_band: "Critical"} = asset) do
    asset
    |> Risk.health_factor()
    |> critical_recommendation_id()
  end

  defp recommendation_id(%{risk_band: "Elevated"}), do: :manual_review
  defp recommendation_id(%{risk_band: "Moderate"}), do: :watch
  defp recommendation_id(_asset), do: :clear

  defp critical_recommendation_id(health_factor) when health_factor < 1.2,
    do: :liquidation_candidate

  defp critical_recommendation_id(_health_factor), do: :manual_review
end
