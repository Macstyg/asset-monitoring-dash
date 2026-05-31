defmodule AssetMonitoringDashWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use AssetMonitoringDashWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  alias AssetMonitoringDash.Seeds.DemoCatalog

  using do
    quote do
      # The default endpoint for testing
      @endpoint AssetMonitoringDashWeb.Endpoint

      use AssetMonitoringDashWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import AssetMonitoringDashWeb.ConnCase
    end
  end

  setup tags do
    AssetMonitoringDash.DataCase.setup_sandbox(tags)
    AssetMonitoringDash.AssetScenarioStore.reset_all()
    AssetMonitoringDash.EventStore.reset_all()
    AssetMonitoringDash.ReviewStore.reset_all()
    DemoCatalog.run!()

    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  def asset_id(code) do
    AssetMonitoringDash.Assets.persisted_asset_id(code)
  end

  def asset_row_selector(code), do: "#asset-row-#{asset_id(code)}"
  def related_asset_selector(code), do: "#related-asset-#{asset_id(code)}"

  def event_id(prefix, code), do: "#{prefix}-#{asset_id(code)}"
  def event_row_selector(prefix, code), do: "#event-row-#{event_id(prefix, code)}"
  def asset_event_row_selector(prefix, code), do: "#asset-event-row-#{event_id(prefix, code)}"
end
