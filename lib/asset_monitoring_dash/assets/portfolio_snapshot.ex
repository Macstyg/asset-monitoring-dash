defmodule AssetMonitoringDash.Assets.PortfolioSnapshot do
  @moduledoc """
  Persisted aggregate market observation for the portfolio dashboard.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "portfolio_snapshots" do
    field :average_ltv_percent, :decimal
    field :liquidation_candidate_count, :integer
    field :observed_at, :utc_datetime
    field :risk_score, :integer
    field :source, :string
    field :total_collateral_value_usd, :decimal
    field :weighted_apy_percent, :decimal

    timestamps(type: :utc_datetime)
  end

  def changeset(snapshot, attrs) do
    snapshot
    |> cast(attrs, [
      :average_ltv_percent,
      :liquidation_candidate_count,
      :observed_at,
      :risk_score,
      :source,
      :total_collateral_value_usd,
      :weighted_apy_percent
    ])
    |> validate_required([
      :average_ltv_percent,
      :liquidation_candidate_count,
      :observed_at,
      :risk_score,
      :source,
      :total_collateral_value_usd,
      :weighted_apy_percent
    ])
    |> validate_number(:liquidation_candidate_count, greater_than_or_equal_to: 0)
    |> validate_number(:risk_score, greater_than_or_equal_to: 0, less_than_or_equal_to: 100)
    |> unique_constraint(:observed_at)
  end
end
