defmodule AssetMonitoringDash.Repo.Migrations.CreateAssetCatalog do
  use Ecto.Migration

  def change do
    create table(:chains) do
      add :name, :string, null: false
      add :slug, :string, null: false
      add :native_token, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:chains, [:slug])
    create unique_index(:chains, [:name])

    create table(:game_ecosystems) do
      add :name, :string, null: false
      add :slug, :string, null: false
      add :genre, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:game_ecosystems, [:slug])
    create unique_index(:game_ecosystems, [:name])

    create table(:monitored_assets, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :name, :string, null: false
      add :icon, :string, null: false
      add :asset_type, :string, null: false
      add :rarity, :string, null: false
      add :floor_price_usd, :decimal, precision: 14, scale: 2, null: false
      add :current_value_usd, :decimal, precision: 14, scale: 2, null: false
      add :loan_value_usd, :decimal, precision: 14, scale: 2, null: false
      add :ltv_percent, :decimal, precision: 7, scale: 2, null: false
      add :risk_score, :integer, null: false
      add :risk_band, :string, null: false
      add :oracle_freshness_seconds, :integer, null: false
      add :market_depth_usd, :decimal, precision: 14, scale: 2, null: false

      add :chain_id, references(:chains, on_delete: :restrict), null: false
      add :game_ecosystem_id, references(:game_ecosystems, on_delete: :restrict), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:monitored_assets, [:name])
    create index(:monitored_assets, [:chain_id])
    create index(:monitored_assets, [:game_ecosystem_id])
    create index(:monitored_assets, [:risk_band])

    create table(:asset_market_snapshots, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :asset_id, references(:monitored_assets, type: :uuid, on_delete: :delete_all),
        null: false

      add :floor_price_usd, :decimal, precision: 14, scale: 2, null: false
      add :current_value_usd, :decimal, precision: 14, scale: 2, null: false
      add :loan_value_usd, :decimal, precision: 14, scale: 2, null: false
      add :ltv_percent, :decimal, precision: 7, scale: 2, null: false
      add :oracle_freshness_seconds, :integer, null: false
      add :market_depth_usd, :decimal, precision: 14, scale: 2, null: false
      add :source, :string, null: false
      add :observed_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:asset_market_snapshots, [:asset_id, :observed_at])
    create index(:asset_market_snapshots, [:asset_id])
    create index(:asset_market_snapshots, [:observed_at])
  end
end
