defmodule AssetMonitoringDashWeb.ComponentCase do
  @moduledoc """
  Test case for rendering function components without database setup.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      @endpoint AssetMonitoringDashWeb.Endpoint

      use AssetMonitoringDashWeb, :verified_routes

      import Phoenix.LiveViewTest
    end
  end
end
