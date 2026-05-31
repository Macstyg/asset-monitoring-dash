defmodule AssetMonitoringDash.Repo.Migrations.CreateReviewDecisions do
  use Ecto.Migration

  def change do
    create table(:review_decisions, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :asset_id, references(:monitored_assets, type: :uuid, on_delete: :delete_all),
        null: false

      add :state_id, :string, null: false
      add :actor, :string, null: false
      add :reason, :string, null: false, default: ""
      add :note, :string, null: false, default: ""
      add :occurred_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:review_decisions, [:asset_id, :occurred_at])
    create index(:review_decisions, [:asset_id, :id])

    create table(:asset_scenarios, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :asset_id, references(:monitored_assets, type: :uuid, on_delete: :delete_all),
        null: false

      add :scenario_id, :string, null: false
      add :drop_percent, :integer, null: false
      add :current_value_usd, :decimal, precision: 14, scale: 2, null: false
      add :ltv_percent, :decimal, precision: 7, scale: 2, null: false
      add :risk_score, :integer, null: false
      add :risk_band, :string, null: false
      add :applied_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:asset_scenarios, [:asset_id, :scenario_id])

    create table(:activity_events, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :event_key, :string, null: false

      add :asset_id, references(:monitored_assets, type: :uuid, on_delete: :delete_all)

      add :kind, :string, null: false
      add :actor, :string, null: false
      add :status, :string, null: false
      add :tone, :string, null: false
      add :title, :string, null: false
      add :detail, :text, null: false
      add :chain, :string, null: false
      add :review_reason, :string, null: false, default: ""
      add :operator_note, :string, null: false, default: ""
      add :occurred_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:activity_events, [:event_key])
    create index(:activity_events, [:asset_id, :occurred_at])
    create index(:activity_events, [:occurred_at])
  end
end
