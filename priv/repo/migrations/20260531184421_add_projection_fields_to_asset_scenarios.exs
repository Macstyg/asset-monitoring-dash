defmodule AssetMonitoringDash.Repo.Migrations.AddProjectionFieldsToAssetScenarios do
  use Ecto.Migration

  def change do
    alter table(:asset_scenarios) do
      add :loan_value_usd, :decimal, precision: 14, scale: 2
      add :market_depth_usd, :decimal, precision: 14, scale: 2
      add :oracle_freshness_seconds, :integer
    end

    execute(
      """
      UPDATE asset_scenarios AS scenario
      SET loan_value_usd = asset.loan_value_usd,
          market_depth_usd = asset.market_depth_usd,
          oracle_freshness_seconds = asset.oracle_freshness_seconds
      FROM monitored_assets AS asset
      WHERE scenario.asset_id = asset.id
      """,
      ""
    )

    alter table(:asset_scenarios) do
      modify :loan_value_usd, :decimal, precision: 14, scale: 2, null: false
      modify :market_depth_usd, :decimal, precision: 14, scale: 2, null: false
      modify :oracle_freshness_seconds, :integer, null: false
    end
  end
end
