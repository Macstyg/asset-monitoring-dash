defmodule AssetMonitoringDash.Assets.MonitoredAsset do
  @moduledoc """
  Persisted collateral asset monitored by the risk cockpit.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias AssetMonitoringDash.Assets.Chain
  alias AssetMonitoringDash.Assets.GameEcosystem
  alias AssetMonitoringDash.Assets.MarketSnapshot

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "monitored_assets" do
    field :asset_type, :string
    field :current_value_usd, :decimal
    field :floor_price_usd, :decimal
    field :icon, :string
    field :loan_value_usd, :decimal
    field :ltv_percent, :decimal
    field :market_depth_usd, :decimal
    field :name, :string
    field :oracle_freshness_seconds, :integer
    field :rarity, :string
    field :risk_band, :string
    field :risk_score, :integer

    belongs_to :chain, Chain
    belongs_to :game_ecosystem, GameEcosystem
    has_many :market_snapshots, MarketSnapshot, foreign_key: :asset_id

    timestamps(type: :utc_datetime)
  end

  def changeset(monitored_asset, attrs) do
    monitored_asset
    |> cast(attrs, [
      :asset_type,
      :chain_id,
      :current_value_usd,
      :floor_price_usd,
      :game_ecosystem_id,
      :icon,
      :loan_value_usd,
      :ltv_percent,
      :market_depth_usd,
      :name,
      :oracle_freshness_seconds,
      :rarity,
      :risk_band,
      :risk_score
    ])
    |> validate_required([
      :asset_type,
      :chain_id,
      :current_value_usd,
      :floor_price_usd,
      :game_ecosystem_id,
      :icon,
      :loan_value_usd,
      :ltv_percent,
      :market_depth_usd,
      :name,
      :oracle_freshness_seconds,
      :rarity,
      :risk_band,
      :risk_score
    ])
    |> foreign_key_constraint(:chain_id)
    |> foreign_key_constraint(:game_ecosystem_id)
  end
end
