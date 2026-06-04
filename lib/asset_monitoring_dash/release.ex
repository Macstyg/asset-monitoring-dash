defmodule AssetMonitoringDash.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  alias Ecto.Migrator

  alias AssetMonitoringDash.Seeds.DemoCatalog

  @app :asset_monitoring_dash

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Migrator.with_repo(repo, &Migrator.run(&1, :up, all: true))
    end
  end

  def migrate_and_seed do
    migrate()
    seed()
  end

  def seed do
    load_app()

    for repo <- repos() do
      {:ok, _, _} =
        Migrator.with_repo(repo, fn _repo ->
          DemoCatalog.run!()
        end)
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Migrator.with_repo(repo, &Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    # Many platforms require SSL when connecting to the database
    Application.ensure_all_started(:ssl)
    Application.ensure_loaded(@app)
  end
end
