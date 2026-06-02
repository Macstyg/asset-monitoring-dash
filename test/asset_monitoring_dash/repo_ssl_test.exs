defmodule AssetMonitoringDash.RepoSSLTest do
  use ExUnit.Case, async: true

  alias AssetMonitoringDash.RepoSSL

  test "keeps database SSL disabled by default" do
    assert RepoSSL.from_env(env(%{})) == false
  end

  test "enables database SSL with system CA certificates" do
    ssl = RepoSSL.from_env(env(%{"ECTO_SSL" => "true"}))

    assert is_list(ssl)
    assert Keyword.has_key?(ssl, :cacerts)
  end

  test "treats 1 as an enabled SSL flag" do
    ssl = RepoSSL.from_env(env(%{"ECTO_SSL" => "1"}))

    assert is_list(ssl)
    assert Keyword.has_key?(ssl, :cacerts)
  end

  test "uses a provider CA certificate file when supplied" do
    assert RepoSSL.from_env(env(%{"ECTO_SSL" => "true", "DB_CA_CERT_FILE" => "/certs/db-ca.pem"})) ==
             [cacertfile: "/certs/db-ca.pem"]
  end

  test "ignores blank provider CA certificate paths" do
    ssl = RepoSSL.from_env(env(%{"ECTO_SSL" => "true", "DB_CA_CERT_FILE" => "   "}))

    assert is_list(ssl)
    assert Keyword.has_key?(ssl, :cacerts)
  end

  defp env(values) do
    fn key -> Map.get(values, key) end
  end
end
