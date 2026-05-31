ExUnit.start()

AssetMonitoringDash.Repo.delete_all(AssetMonitoringDash.AssetScenario)
AssetMonitoringDash.Repo.delete_all(AssetMonitoringDash.ActivityEventRecord)
AssetMonitoringDash.Repo.delete_all(AssetMonitoringDash.ReviewDecisionRecord)
AssetMonitoringDash.Seeds.DemoCatalog.run!()

Ecto.Adapters.SQL.Sandbox.mode(AssetMonitoringDash.Repo, :manual)
