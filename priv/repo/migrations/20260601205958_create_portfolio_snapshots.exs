defmodule AssetMonitoringDash.Repo.Migrations.CreatePortfolioSnapshots do
  use Ecto.Migration

  def change do
    create table(:portfolio_snapshots, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :total_collateral_value_usd, :decimal, precision: 16, scale: 2, null: false
      add :weighted_apy_percent, :decimal, precision: 7, scale: 2, null: false
      add :average_ltv_percent, :decimal, precision: 7, scale: 2, null: false
      add :risk_score, :integer, null: false
      add :liquidation_candidate_count, :integer, null: false
      add :source, :string, null: false
      add :observed_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:portfolio_snapshots, [:observed_at])
  end
end
