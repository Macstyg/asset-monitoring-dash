defmodule AssetMonitoringDash.EndpointOrigin do
  @moduledoc """
  Builds the production `:check_origin` setting for Phoenix sockets.

  By default Phoenix checks LiveView/WebSocket origins against the configured
  endpoint host. `PHX_CHECK_ORIGIN` can be used to allow an explicit list of
  deployment origins, for example a custom domain plus a platform preview URL.
  """

  @type config :: true | [String.t()]
  @type env_reader :: (String.t() -> String.t() | nil)

  @spec from_env(env_reader()) :: config()
  def from_env(env_reader \\ &System.get_env/1) when is_function(env_reader, 1) do
    env_reader.("PHX_CHECK_ORIGIN")
    |> origins()
  end

  defp origins(value) when is_binary(value) do
    value
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> origins_from_list()
  end

  defp origins(_value), do: true

  defp origins_from_list([]), do: true
  defp origins_from_list(origins), do: origins
end
