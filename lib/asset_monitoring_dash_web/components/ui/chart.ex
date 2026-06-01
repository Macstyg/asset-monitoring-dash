defmodule AssetMonitoringDashWeb.UI.Chart do
  @moduledoc """
  ECharts-backed chart primitive.

  Elixir owns the chart option data, while the browser hook owns the canvas
  lifecycle and theme-aware rendering.
  """

  use Phoenix.Component

  attr :class, :string, default: ""
  attr :id, :string, required: true
  attr :option, :map, required: true
  attr :rest, :global

  def render(assigns) do
    ~H"""
    <div
      id={@id}
      phx-hook="EChart"
      phx-update="ignore"
      data-chart-option={Jason.encode!(@option)}
      class={[
        "min-h-64 w-full",
        @class
      ]}
      {@rest}
    >
    </div>
    """
  end
end
