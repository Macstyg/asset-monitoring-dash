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

  alias AssetMonitoringDash.Accounts
  alias AssetMonitoringDash.Accounts.Scope
  alias AssetMonitoringDash.AccountsFixtures

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

  @doc """
  Setup helper that registers and logs in users.

      setup :register_and_log_in_user

  It stores an updated connection and a registered user in the
  test context.
  """
  def register_and_log_in_user(%{conn: conn} = context) do
    user = AccountsFixtures.user_fixture()
    scope = Scope.for_user(user)

    opts =
      context
      |> Map.take([:token_authenticated_at])
      |> Enum.into([])

    %{conn: log_in_user(conn, user, opts), user: user, scope: scope}
  end

  @doc """
  Logs the given `user` into the `conn`.

  It returns an updated `conn`.
  """
  def log_in_user(conn, user, opts \\ []) do
    token = Accounts.generate_user_session_token(user)

    maybe_set_token_authenticated_at(token, opts[:token_authenticated_at])

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:user_token, token)
  end

  defp maybe_set_token_authenticated_at(_token, nil), do: nil

  defp maybe_set_token_authenticated_at(token, authenticated_at) do
    AccountsFixtures.override_token_authenticated_at(token, authenticated_at)
  end
end
