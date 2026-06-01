defmodule AssetMonitoringDashWeb.AssetLive.Components.AssetTrend do
  @moduledoc """
  Compact LTV trend for the selected asset inspection panel.
  """

  use Phoenix.Component

  alias AssetMonitoringDashWeb.Formatters
  alias AssetMonitoringDashWeb.UI.Card
  alias AssetMonitoringDashWeb.UI.Chart

  attr :points, :list, required: true

  def render(assigns) do
    assigns =
      assigns
      |> assign(:first_point, List.first(assigns.points))
      |> assign(:latest_point, List.last(assigns.points))
      |> assign(:delta, trend_delta(assigns.points))
      |> assign(:chart_option, chart_option(assigns.points))

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

      <Chart.render
        id="asset-ltv-trend-chart"
        option={@chart_option}
        class="mt-4 h-64 min-h-64"
        aria-label={"Selected asset LTV moved from #{Formatters.ltv(@first_point.value)} to #{Formatters.ltv(@latest_point.value)}"}
      />

      <div class="mt-1 flex items-center justify-between font-mono text-xs text-app-muted">
        <span>{@first_point.label}</span>
        <span>{@latest_point.label}</span>
      </div>
    </Card.surface>
    """
  end

  defp chart_option(points) do
    values = Enum.map(points, &decimal_to_float(&1.value))

    %{
      animationDuration: 350,
      grid: %{bottom: 10, containLabel: true, left: 8, right: 8, top: 16},
      series: [
        %{
          areaStyle: %{color: "rgba(245, 183, 10, 0.12)"},
          data: Enum.map(points, &chart_point/1),
          itemStyle: %{color: "#f5b70a", borderColor: "css:--amd-surface", borderWidth: 2},
          lineStyle: %{color: "#f5b70a", width: 3},
          markLine: threshold_lines(),
          name: "LTV",
          showSymbol: true,
          smooth: true,
          symbolSize: 8,
          type: "line"
        }
      ],
      tooltip: axis_tooltip(),
      xAxis: category_axis(Enum.map(points, & &1.label)),
      yAxis: value_axis(values)
    }
  end

  defp chart_point(point) do
    %{
      tooltipLabel: "LTV",
      tooltipValue: Formatters.ltv(point.value),
      value: decimal_to_float(point.value)
    }
  end

  defp threshold_lines do
    %{
      data: [
        threshold_line("Watch", 60, "#f5b70a"),
        threshold_line("Review", 75, "#f87171"),
        threshold_line("Liquidation candidate", 80, "#ef4444")
      ],
      label: %{
        color: "css:--amd-muted",
        fontFamily: "var(--amd-font-mono)",
        formatter: "{b}",
        position: "insideEndTop"
      },
      lineStyle: %{type: "dashed", width: 1},
      silent: true,
      symbol: "none"
    }
  end

  defp threshold_line(name, value, color) do
    %{
      lineStyle: %{color: color},
      name: "#{value}% #{name}",
      yAxis: value
    }
  end

  defp axis_tooltip do
    %{
      axisPointer: %{
        lineStyle: %{color: "css:--amd-border", type: "dashed", width: 1},
        type: "line"
      },
      backgroundColor: "css:--amd-surface",
      borderColor: "css:--amd-border",
      borderRadius: 8,
      borderWidth: 1,
      confine: true,
      padding: [10, 12],
      textStyle: %{color: "css:--amd-fg"},
      titlePrefix: "Observation",
      trigger: "axis"
    }
  end

  defp category_axis(labels) do
    %{
      axisLabel: %{color: "css:--amd-muted", fontFamily: "var(--amd-font-mono)"},
      axisLine: %{lineStyle: %{color: "css:--amd-border"}},
      axisTick: %{show: false},
      data: labels,
      type: "category"
    }
  end

  defp value_axis(values) do
    %{
      axisLabel: %{
        color: "css:--amd-muted",
        formatter: "{value}%",
        fontFamily: "var(--amd-font-mono)"
      },
      max: y_axis_max(values),
      min: y_axis_min(values),
      splitLine: %{lineStyle: %{color: "css:--amd-border", type: "dashed"}},
      type: "value"
    }
  end

  defp y_axis_min(values) do
    values
    |> Enum.min(fn -> 0.0 end)
    |> min(60.0)
    |> Kernel.-(4.0)
    |> Float.floor(0)
    |> max(0.0)
  end

  defp y_axis_max(values) do
    values
    |> Enum.max(fn -> 80.0 end)
    |> max(80.0)
    |> Kernel.+(4.0)
    |> Float.ceil(0)
  end

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
