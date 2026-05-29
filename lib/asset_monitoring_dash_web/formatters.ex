defmodule AssetMonitoringDashWeb.Formatters do
  @moduledoc """
  Formatting helpers for dashboard display values.
  """

  def compact_usd(value) when is_integer(value) do
    "$#{decimal(value / 1_000_000)}M"
  end

  def usd(value) when is_integer(value) do
    "$#{number(value)}"
  end

  def ltv(value) do
    "#{decimal(value)}%"
  end

  def signed_percent(value) when value > 0, do: "+#{decimal(value)}%"
  def signed_percent(value), do: "#{decimal(value)}%"

  def duration_seconds(value) when is_integer(value) and value < 60, do: "#{value}s"

  def duration_seconds(value) when is_integer(value) and value < 3_600 do
    "#{div(value, 60)}m"
  end

  def duration_seconds(value) when is_integer(value) do
    "#{div(value, 3_600)}h"
  end

  def decimal(value) do
    :erlang.float_to_binary(value / 1, decimals: 1)
  end

  def number(value) when is_integer(value) do
    value
    |> Integer.to_string()
    |> String.replace(~r/\B(?=(\d{3})+(?!\d))/, ",")
  end
end
