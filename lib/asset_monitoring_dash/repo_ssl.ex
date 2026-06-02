defmodule AssetMonitoringDash.RepoSSL do
  @moduledoc """
  Builds PostgreSQL SSL options from deployment environment variables.

  Local development and tests keep SSL disabled by default. Hosted Postgres
  deployments can opt in with `ECTO_SSL=true` and optionally provide a
  provider CA bundle with `DB_CA_CERT_FILE`.
  """

  @type config :: false | keyword()
  @type env_reader :: (String.t() -> String.t() | nil)

  @spec from_env(env_reader()) :: config()
  def from_env(env_reader \\ &System.get_env/1) when is_function(env_reader, 1) do
    env_reader.("ECTO_SSL")
    |> ssl_enabled?()
    |> ssl_config(env_reader)
  end

  defp ssl_enabled?(value) when is_binary(value) do
    value
    |> String.trim()
    |> String.downcase()
    |> enabled_value?()
  end

  defp ssl_enabled?(_value), do: false

  defp enabled_value?("1"), do: true
  defp enabled_value?("true"), do: true
  defp enabled_value?(_value), do: false

  defp ssl_config(false, _env_reader), do: false

  defp ssl_config(true, env_reader) do
    env_reader.("DB_CA_CERT_FILE")
    |> ssl_options()
  end

  defp ssl_options(path) when is_binary(path) do
    path
    |> String.trim()
    |> ssl_options_for_cert_path()
  end

  defp ssl_options(_path), do: default_ssl_options()

  defp ssl_options_for_cert_path(""), do: default_ssl_options()
  defp ssl_options_for_cert_path(path), do: [cacertfile: path]

  defp default_ssl_options do
    [cacerts: :public_key.cacerts_get()]
  end
end
