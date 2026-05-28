defmodule AssetMonitoringDash.DemoData do
  @moduledoc """
  Deterministic demo data for the first dashboard slices.

  The values here are deliberately small and explicit while the product shape is
  still forming. Later milestones can replace these functions with Ecto-backed
  contexts without forcing the LiveView to know where the data came from.
  """

  def portfolio_snapshot do
    %{
      total_collateral_value_usd: 12_840_000,
      collateral_delta_percent: 4.8,
      active_loans: 132,
      active_loans_delta: 9,
      weighted_apy_percent: 13.7,
      apy_delta_percent: -0.4,
      risk_score: 68,
      risk_delta: 6,
      risk_band: "Elevated"
    }
  end
end
