defmodule AssetMonitoringDashWeb.Formatters do
  @moduledoc """
  Formatting helpers for dashboard display values.
  """

  alias AssetMonitoringDash.Money

  def compact_usd(value) do
    value = Money.decimal(value)

    cond do
      decimal_gte?(value, 1_000_000) -> "$#{decimal(Decimal.div(value, 1_000_000))}M"
      decimal_gte?(value, 1_000) -> "$#{decimal(Decimal.div(value, 1_000))}K"
      true -> usd(value)
    end
  end

  def usd(value) do
    "$#{number(value)}"
  end

  def ltv(value) do
    "#{decimal(value)}%"
  end

  def signed_percent(value) do
    case Decimal.compare(Money.decimal(value), Decimal.new("0")) do
      :gt -> "+#{decimal(value)}%"
      _comparison -> "#{decimal(value)}%"
    end
  end

  def duration_seconds(value) when is_integer(value) and value < 60, do: "#{value}s"

  def duration_seconds(value) when is_integer(value) and value < 3_600 do
    "#{div(value, 60)}m"
  end

  def duration_seconds(value) when is_integer(value) do
    "#{div(value, 3_600)}h"
  end

  def decimal(value) do
    value
    |> Money.decimal()
    |> Decimal.round(1)
    |> normalize_zero()
    |> Decimal.to_string(:normal)
  end

  defp normalize_zero(decimal) do
    case Decimal.compare(decimal, Decimal.new("0")) do
      :eq -> Decimal.new("0.0")
      _comparison -> decimal
    end
  end

  defp number(value) do
    value
    |> Money.decimal()
    |> Decimal.round(0)
    |> Decimal.to_integer()
    |> Integer.to_string()
    |> String.replace(~r/\B(?=(\d{3})+(?!\d))/, ",")
  end

  defp decimal_gte?(value, threshold),
    do: Decimal.compare(Money.decimal(value), Money.decimal(threshold)) in [:gt, :eq]
end
