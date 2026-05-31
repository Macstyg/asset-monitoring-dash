defmodule AssetMonitoringDash.AssetScenario do
  @moduledoc """
  Persisted scenario projection for demo controls applied to a monitored asset.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "asset_scenarios" do
    field :applied_at, :utc_datetime_usec
    field :asset_id, :binary_id
    field :current_value_usd, :decimal
    field :drop_percent, :integer
    field :loan_value_usd, :decimal
    field :ltv_percent, :decimal
    field :market_depth_usd, :decimal
    field :oracle_freshness_seconds, :integer
    field :risk_band, :string
    field :risk_score, :integer
    field :scenario_id, :string

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(asset_scenario, attrs) do
    asset_scenario
    |> cast(attrs, [
      :applied_at,
      :asset_id,
      :current_value_usd,
      :drop_percent,
      :loan_value_usd,
      :ltv_percent,
      :market_depth_usd,
      :oracle_freshness_seconds,
      :risk_band,
      :risk_score,
      :scenario_id
    ])
    |> validate_required([
      :applied_at,
      :asset_id,
      :current_value_usd,
      :drop_percent,
      :loan_value_usd,
      :ltv_percent,
      :market_depth_usd,
      :oracle_freshness_seconds,
      :risk_band,
      :risk_score,
      :scenario_id
    ])
  end
end
