defmodule AssetMonitoringDashWeb.AssetLive.Components.AssetTrend do
  @moduledoc """
  Compact LTV trend for the selected asset inspection panel.
  """

  use Phoenix.Component

  alias AssetMonitoringDashWeb.Formatters
  alias AssetMonitoringDashWeb.UI.Card

  attr :points, :list, required: true

  def render(assigns) do
    assigns =
      assigns
      |> assign(:path, line_path(assigns.points))
      |> assign(:area_path, area_path(assigns.points))
      |> assign(:first_point, List.first(assigns.points))
      |> assign(:latest_point, List.last(assigns.points))
      |> assign(:delta, trend_delta(assigns.points))

    ~H"""
    <Card.surface
      id="asset-ltv-trend"
      variant={:inset}
      class="mt-4"
    >
      <div class="flex items-start justify-between gap-3">
        <div>
          <p class="font-mono text-xs uppercase tracking-[0.12em] text-app-muted">LTV trend</p>
          <p class="mt-1 text-sm text-app-muted">Persisted market observations for this asset.</p>
        </div>
        <div class="shrink-0 text-right">
          <p
            id="asset-ltv-trend-latest"
            class="font-mono text-sm font-semibold tabular-nums text-app-fg"
          >
            {Formatters.ltv(@latest_point.value)}
          </p>
          <p
            id="asset-ltv-trend-delta"
            class={["mt-1 font-mono text-xs font-semibold", delta_class(@delta)]}
          >
            {format_delta(@delta)}
          </p>
        </div>
      </div>

      <svg
        class="mt-4 h-24 w-full overflow-visible"
        viewBox="0 0 240 88"
        role="img"
        aria-labelledby="asset-ltv-trend-title"
        preserveAspectRatio="none"
      >
        <title id="asset-ltv-trend-title">
          Selected asset LTV moved from {Formatters.ltv(@first_point.value)} to {Formatters.ltv(
            @latest_point.value
          )}
        </title>
        <path d={@area_path} class="fill-app-warn/10" />
        <path
          d={@path}
          class="fill-none stroke-app-warn"
          stroke-width="3"
          stroke-linecap="round"
          stroke-linejoin="round"
          vector-effect="non-scaling-stroke"
        />
        <circle
          :for={point <- chart_points(@points)}
          cx={point.x}
          cy={point.y}
          r="3"
          class="fill-app-surface stroke-app-warn"
          stroke-width="2"
          vector-effect="non-scaling-stroke"
        />
      </svg>

      <div class="mt-2 flex items-center justify-between font-mono text-xs text-app-muted">
        <span>{@first_point.label}</span>
        <span>{@latest_point.label}</span>
      </div>
    </Card.surface>
    """
  end

  defp chart_points(points) do
    values = Enum.map(points, &decimal_to_float(&1.value))
    min_value = Enum.min(values)
    max_value = Enum.max(values)
    range = chart_range(max_value - min_value)
    step = 228 / max(length(points) - 1, 1)

    points
    |> Enum.with_index()
    |> Enum.map(fn {point, index} ->
      %{
        label: point.label,
        value: point.value,
        x: Float.round(6 + index * step, 2),
        y: Float.round(76 - (decimal_to_float(point.value) - min_value) / range * 64, 2)
      }
    end)
  end

  defp line_path(points) do
    points
    |> chart_points()
    |> Enum.with_index()
    |> Enum.map_join(" ", fn {point, index} -> line_command(point, index) end)
  end

  defp area_path(points) do
    chart_points = chart_points(points)
    first_point = List.first(chart_points)
    last_point = List.last(chart_points)

    "#{line_path(points)} L #{last_point.x} 82 L #{first_point.x} 82 Z"
  end

  defp line_command(point, 0), do: "M #{point.x} #{point.y}"
  defp line_command(point, _index), do: "L #{point.x} #{point.y}"

  defp chart_range(range) when range <= 0.0, do: 1.0
  defp chart_range(range), do: range

  defp trend_delta(points) do
    Decimal.sub(decimal(List.last(points).value), decimal(List.first(points).value))
  end

  defp format_delta(delta) do
    case Decimal.compare(decimal(delta), Decimal.new("0")) do
      :gt -> "+#{Formatters.decimal(delta)} pts"
      :lt -> "#{Formatters.decimal(delta)} pts"
      :eq -> "0.0 pts"
    end
  end

  defp delta_class(delta) do
    case Decimal.compare(decimal(delta), Decimal.new("0")) do
      :gt -> "text-app-warn"
      :lt -> "text-app-accent"
      :eq -> "text-app-muted"
    end
  end

  defp decimal(%Decimal{} = value), do: value
  defp decimal(value) when is_integer(value), do: Decimal.new(value)

  defp decimal(value) when is_float(value) do
    value
    |> Float.to_string()
    |> Decimal.new()
  end

  defp decimal_to_float(value), do: value |> decimal() |> Decimal.to_float()
end
