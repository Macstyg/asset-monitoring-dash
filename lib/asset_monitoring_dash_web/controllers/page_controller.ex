defmodule AssetMonitoringDashWeb.PageController do
  use AssetMonitoringDashWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
