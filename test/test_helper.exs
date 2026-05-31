ExUnit.start()

AssetMonitoringDash.DemoOperations.reset_mutable_state()
AssetMonitoringDash.Seeds.DemoCatalog.run!()

Ecto.Adapters.SQL.Sandbox.mode(AssetMonitoringDash.Repo, :manual)
