defmodule AssetMonitoringDash.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      AssetMonitoringDashWeb.Telemetry,
      AssetMonitoringDash.Repo,
      AssetMonitoringDash.AssetScenarioStore,
      AssetMonitoringDash.EventStore,
      AssetMonitoringDash.ReviewStore,
      {DNSCluster,
       query: Application.get_env(:asset_monitoring_dash, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: AssetMonitoringDash.PubSub},
      # Start a worker by calling: AssetMonitoringDash.Worker.start_link(arg)
      # {AssetMonitoringDash.Worker, arg},
      # Start to serve requests, typically the last entry
      AssetMonitoringDashWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: AssetMonitoringDash.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    AssetMonitoringDashWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
