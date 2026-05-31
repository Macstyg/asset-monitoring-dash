defmodule AssetMonitoringDash.Money do
  @moduledoc """
  Small Decimal-backed helper for USD values used by the demo domain.

  We keep this intentionally lightweight until the product needs multiple
  currencies, FX conversion, or currency-specific rounding rules.
  """

  @usd_scale 2

  def usd(value), do: decimal(value) |> Decimal.round(@usd_scale)

  def multiply(value, multiplier) do
    value
    |> decimal()
    |> Decimal.mult(decimal(multiplier))
    |> usd()
  end

  def divide(value, divisor) do
    value
    |> decimal()
    |> Decimal.div(decimal(divisor))
    |> usd()
  end

  def sum(values) do
    values
    |> Enum.reduce(decimal(0), fn value, total -> Decimal.add(total, decimal(value)) end)
    |> usd()
  end

  def max(value, minimum) do
    case Decimal.compare(decimal(value), decimal(minimum)) do
      :lt -> usd(minimum)
      _comparison -> usd(value)
    end
  end

  def decimal(%Decimal{} = value), do: value
  def decimal(value) when is_integer(value), do: Decimal.new(value)

  def decimal(value) when is_float(value) do
    value
    |> Float.to_string()
    |> Decimal.new()
  end

  def decimal(value) when is_binary(value), do: Decimal.new(value)
end
