defmodule AssetMonitoringDashWeb.AssetLive.Components.AssetTrend do
  @moduledoc """
  Compact LTV trend for the selected asset inspection panel.
  """

  use Phoenix.Component

  alias AssetMonitoringDashWeb.ChartOptions
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
      |> assign(:chart_option, ChartOptions.asset_ltv_trend(assigns.points))

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
end
