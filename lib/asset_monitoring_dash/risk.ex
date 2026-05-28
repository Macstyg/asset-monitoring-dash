defmodule AssetMonitoringDash.Risk do
  @moduledoc """
  Risk calculations for collateral-backed positions.
  """

  @liquidation_buffer 0.85

  def health_factor(asset) do
    asset.current_value_usd * @liquidation_buffer / asset.loan_value_usd
  end
end
