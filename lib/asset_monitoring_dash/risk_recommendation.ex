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
    |> recommendation_reason()
    |> recommendation_with_reason()
  end

  def recommendation(:clear), do: @recommendations.clear
  def recommendation(:watch), do: @recommendations.watch
  def recommendation(:manual_review), do: @recommendations.manual_review
  def recommendation(:liquidation_candidate), do: @recommendations.liquidation_candidate

  defp recommendation_with_reason({recommendation_id, reason}) do
    recommendation_id
    |> recommendation()
    |> Map.put(:reasons, [reason])
  end

  defp recommendation_reason(%{oracle_status: "Stale", risk_band: risk_band})
       when risk_band in ["Moderate", "Elevated", "Critical"] do
    {:manual_review,
     %{
       id: :stale_oracle,
       label: "Stale oracle",
       detail: "Price data is too old for automated escalation."
     }}
  end

  defp recommendation_reason(%{oracle_status: "Stale"}) do
    {:watch,
     %{
       id: :stale_oracle,
       label: "Stale oracle",
       detail: "Low financial risk still needs monitoring until the feed refreshes."
     }}
  end

  defp recommendation_reason(%{oracle_status: "Delayed", risk_band: "Critical"}) do
    {:manual_review,
     %{
       id: :delayed_oracle,
       label: "Delayed oracle",
       detail: "Critical risk should be reviewed because the price feed is delayed."
     }}
  end

  defp recommendation_reason(%{liquidity_status: "Illiquid", risk_band: risk_band})
       when risk_band in ["Moderate", "Elevated", "Critical"] do
    {:manual_review,
     %{
       id: :illiquid_market,
       label: "Illiquid market",
       detail: "Market depth is too thin to rely on the displayed valuation."
     }}
  end

  defp recommendation_reason(%{liquidity_status: "Illiquid"}) do
    {:watch,
     %{
       id: :illiquid_market,
       label: "Illiquid market",
       detail: "Low financial risk is worth watching because exits may be difficult."
     }}
  end

  defp recommendation_reason(%{risk_band: "Critical"} = asset) do
    asset
    |> Risk.health_factor()
    |> critical_recommendation_reason()
  end

  defp recommendation_reason(%{risk_band: "Elevated"}) do
    {:manual_review,
     %{
       id: :elevated_risk,
       label: "Elevated risk",
       detail: "Collateral pressure is high enough for analyst review."
     }}
  end

  defp recommendation_reason(%{risk_band: "Moderate"}) do
    {:watch,
     %{
       id: :moderate_risk,
       label: "Moderate risk",
       detail: "The position is stable but should stay on the watchlist."
     }}
  end

  defp recommendation_reason(_asset) do
    {:clear,
     %{
       id: :low_risk,
       label: "Low risk",
       detail: "Collateral, oracle, and liquidity signals look acceptable."
     }}
  end

  defp critical_recommendation_reason(health_factor) do
    case Decimal.compare(health_factor, Decimal.new("1.2")) do
      :lt ->
        {:liquidation_candidate,
         %{
           id: :critical_health,
           label: "Critical health",
           detail: "Risk is critical and the oracle is fresh enough to prepare escalation."
         }}

      _comparison ->
        {:manual_review,
         %{
           id: :critical_risk,
           label: "Critical risk",
           detail: "Risk is critical, but the position still needs analyst confirmation."
         }}
    end
  end
end
