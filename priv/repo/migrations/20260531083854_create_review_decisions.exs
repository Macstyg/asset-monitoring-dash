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
  end
end
