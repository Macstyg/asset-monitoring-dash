defmodule AssetMonitoringDash.Assets.MarketSnapshot do
  @moduledoc """
  Historical market observation for a monitored collateral asset.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias AssetMonitoringDash.Assets.MonitoredAsset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "asset_market_snapshots" do
    field :current_value_usd, :decimal
    field :floor_price_usd, :decimal
    field :loan_value_usd, :decimal
    field :ltv_percent, :decimal
    field :market_depth_usd, :decimal
    field :observed_at, :utc_datetime
    field :oracle_freshness_seconds, :integer
    field :source, :string

    belongs_to :asset, MonitoredAsset, type: :binary_id

    timestamps(type: :utc_datetime)
  end

  def changeset(snapshot, attrs) do
    snapshot
    |> cast(attrs, [
      :asset_id,
      :current_value_usd,
      :floor_price_usd,
      :loan_value_usd,
      :ltv_percent,
      :market_depth_usd,
      :observed_at,
      :oracle_freshness_seconds,
      :source
    ])
    |> validate_required([
      :asset_id,
      :current_value_usd,
      :floor_price_usd,
      :loan_value_usd,
      :ltv_percent,
      :market_depth_usd,
      :observed_at,
      :oracle_freshness_seconds,
      :source
    ])
    |> foreign_key_constraint(:asset_id)
    |> unique_constraint([:asset_id, :observed_at])
  end
end
