defmodule AssetMonitoringDash.Repo do
  use Ecto.Repo,
    otp_app: :asset_monitoring_dash,
    adapter: Ecto.Adapters.Postgres
end
