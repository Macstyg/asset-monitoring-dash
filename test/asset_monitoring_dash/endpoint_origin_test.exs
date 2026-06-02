defmodule AssetMonitoringDash.EndpointOriginTest do
  use ExUnit.Case, async: true

  alias AssetMonitoringDash.EndpointOrigin

  test "uses Phoenix host-based origin checking by default" do
    assert EndpointOrigin.from_env(env(%{})) == true
  end

  test "uses Phoenix host-based origin checking for blank env values" do
    assert EndpointOrigin.from_env(env(%{"PHX_CHECK_ORIGIN" => "   "})) == true
  end

  test "accepts a single explicit origin" do
    assert EndpointOrigin.from_env(env(%{"PHX_CHECK_ORIGIN" => "https://demo.example.com"})) ==
             ["https://demo.example.com"]
  end

  test "accepts multiple explicit origins" do
    assert EndpointOrigin.from_env(
             env(%{
               "PHX_CHECK_ORIGIN" => "https://demo.example.com, https://asset-demo.onrender.com"
             })
           ) == ["https://demo.example.com", "https://asset-demo.onrender.com"]
  end

  test "ignores empty origin entries" do
    assert EndpointOrigin.from_env(env(%{"PHX_CHECK_ORIGIN" => "https://demo.example.com, ,"})) ==
             ["https://demo.example.com"]
  end

  defp env(values) do
    fn key -> Map.get(values, key) end
  end
end
