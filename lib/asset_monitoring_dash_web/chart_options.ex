defmodule AssetMonitoringDashWeb.ChartOptions do
  @moduledoc """
  ECharts option builders for product charts.

  LiveViews own fetching and assigning chart data. This module owns the chart
  presentation contract sent to the shared `UI.Chart` component.
  """

  alias AssetMonitoringDash.Money
  alias AssetMonitoringDashWeb.Formatters

  def event_volume(buckets, source_options) do
    %{
      animationDuration: 350,
      grid: chart_grid(96),
      legend: %{
        itemHeight: 8,
        itemWidth: 8,
        right: 0,
        textStyle: %{color: "css:--amd-muted", fontFamily: "var(--amd-font-mono)"},
        top: 0
      },
      series: Enum.map(source_options, &event_volume_series(&1, buckets)),
      tooltip: axis_tooltip("Window"),
      xAxis: category_axis(Enum.map(buckets, & &1.label)),
      yAxis: value_axis(%{minInterval: 1})
    }
  end

  def risk_pressure(buckets) do
    %{
      animationDuration: 350,
      legend: %{
        bottom: 0,
        itemHeight: 8,
        itemWidth: 8,
        textStyle: %{color: "css:--amd-muted", fontFamily: "var(--amd-font-mono)"}
      },
      series: [
        %{
          data: Enum.map(buckets, &risk_pressure_point/1),
          emphasis: %{disabled: true},
          label: %{
            color: "css:--amd-muted",
            fontFamily: "var(--amd-font-mono)",
            formatter: "{b}"
          },
          labelLine: %{lineStyle: %{color: "css:--amd-border"}},
          name: "Collateral value",
          radius: ["48%", "72%"],
          type: "pie"
        }
      ],
      tooltip: item_tooltip("Risk tier")
    }
  end

  def portfolio_value_trend(points) do
    line_chart(points,
      area_color: "rgba(34, 199, 230, 0.12)",
      name: "Collateral value",
      point_mapper: &portfolio_value_point/1,
      title_prefix: "Snapshot",
      tone: :info
    )
  end

  def portfolio_risk_trend(points) do
    line_chart(points,
      area_color: "rgba(245, 183, 10, 0.12)",
      name: "Risk score",
      point_mapper: &portfolio_risk_point/1,
      title_prefix: "Snapshot",
      tone: :warning,
      y_axis: %{max: 100, min: 0}
    )
  end

  def asset_ltv_trend(points) do
    values = Enum.map(points, &decimal_to_float(&1.value))

    %{
      animationDuration: 350,
      grid: %{bottom: 10, containLabel: true, left: 8, right: 8, top: 16},
      series: [
        %{
          areaStyle: %{color: "rgba(245, 183, 10, 0.12)"},
          data: Enum.map(points, &asset_ltv_point/1),
          itemStyle: %{
            color: chart_color(:warning),
            borderColor: "css:--amd-surface",
            borderWidth: 2
          },
          lineStyle: %{color: chart_color(:warning), width: 3},
          markLine: asset_ltv_threshold_lines(),
          name: "LTV",
          showSymbol: true,
          smooth: true,
          symbolSize: 8,
          type: "line"
        }
      ],
      tooltip: axis_tooltip("Observation"),
      xAxis: category_axis(Enum.map(points, & &1.label)),
      yAxis: ltv_value_axis(values)
    }
  end

  defp event_volume_series(option, buckets) do
    color = chart_color(option.tone)

    %{
      itemStyle: %{
        borderRadius: [4, 4, 0, 0],
        color: color
      },
      emphasis: %{
        disabled: true,
        itemStyle: %{color: color, opacity: 1}
      },
      name: option.label,
      stack: "events",
      type: "bar",
      data: Enum.map(buckets, &Map.get(&1.sources, option.value, 0))
    }
  end

  defp risk_pressure_point(bucket) do
    %{
      itemStyle: %{
        color: chart_color(bucket.tone)
      },
      name: bucket.label,
      tooltipLabel: "Collateral value",
      tooltipValue: Money.format_usd(bucket.collateral_value_usd),
      value: Decimal.to_float(bucket.collateral_value_usd)
    }
  end

  defp portfolio_value_point(point) do
    %{
      tooltipLabel: "Collateral value",
      tooltipValue: point.tooltip_value,
      value: chart_millions(point.value)
    }
  end

  defp portfolio_risk_point(point) do
    %{
      tooltipLabel: "Risk score",
      tooltipValue: point.tooltip_value,
      value: point.value
    }
  end

  defp asset_ltv_point(point) do
    %{
      tooltipLabel: "LTV",
      tooltipValue: Formatters.ltv(point.value),
      value: decimal_to_float(point.value)
    }
  end

  defp line_chart(points, opts) do
    color = chart_color(Keyword.fetch!(opts, :tone))
    point_mapper = Keyword.fetch!(opts, :point_mapper)

    %{
      animationDuration: 350,
      grid: chart_grid(44),
      series: [
        %{
          areaStyle: %{color: Keyword.fetch!(opts, :area_color)},
          data: Enum.map(points, point_mapper),
          emphasis: %{disabled: true},
          itemStyle: %{color: color},
          lineStyle: %{color: color, width: 2},
          name: Keyword.fetch!(opts, :name),
          showSymbol: true,
          smooth: true,
          symbolSize: 7,
          type: "line"
        }
      ],
      tooltip: axis_tooltip(Keyword.fetch!(opts, :title_prefix)),
      xAxis: category_axis(Enum.map(points, & &1.label)),
      yAxis: value_axis(Keyword.get(opts, :y_axis, %{}))
    }
  end

  defp asset_ltv_threshold_lines do
    %{
      data: [
        threshold_line("Watch", 60, chart_color(:warning)),
        threshold_line("Review", 75, chart_color(:danger)),
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

  defp chart_millions(value) do
    value
    |> Decimal.div(Decimal.new(1_000_000))
    |> Decimal.round(2)
    |> Decimal.to_float()
  end

  defp chart_grid(top) do
    %{bottom: 8, containLabel: true, left: 8, right: 8, top: top}
  end

  defp axis_tooltip(title_prefix) do
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
      titlePrefix: title_prefix,
      trigger: "axis"
    }
  end

  defp item_tooltip(title_prefix) do
    %{
      backgroundColor: "css:--amd-surface",
      borderColor: "css:--amd-border",
      borderRadius: 8,
      borderWidth: 1,
      confine: true,
      padding: [10, 12],
      textStyle: %{color: "css:--amd-fg"},
      titlePrefix: title_prefix,
      trigger: "item"
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

  defp value_axis(overrides) do
    %{
      axisLabel: %{color: "css:--amd-muted", fontFamily: "var(--amd-font-mono)"},
      splitLine: %{lineStyle: %{color: "css:--amd-border", type: "dashed"}},
      type: "value"
    }
    |> Map.merge(overrides)
  end

  defp ltv_value_axis(values) do
    %{
      axisLabel: %{
        color: "css:--amd-muted",
        formatter: "{value}%",
        fontFamily: "var(--amd-font-mono)"
      },
      max: ltv_axis_max(values),
      min: ltv_axis_min(values),
      splitLine: %{lineStyle: %{color: "css:--amd-border", type: "dashed"}},
      type: "value"
    }
  end

  defp ltv_axis_min(values) do
    values
    |> Enum.min(fn -> 0.0 end)
    |> min(60.0)
    |> Kernel.-(4.0)
    |> Float.floor(0)
    |> max(0.0)
  end

  defp ltv_axis_max(values) do
    values
    |> Enum.max(fn -> 80.0 end)
    |> max(80.0)
    |> Kernel.+(4.0)
    |> Float.ceil(0)
  end

  defp chart_color(:success), do: "#4ade80"
  defp chart_color(:warning), do: "#f5b70a"
  defp chart_color(:danger), do: "#f87171"
  defp chart_color(:info), do: "#22c7e6"
  defp chart_color(_tone), do: "#94a3b8"

  defp decimal_to_float(value), do: value |> Money.decimal() |> Decimal.to_float()
end
