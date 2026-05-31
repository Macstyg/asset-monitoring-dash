defmodule AssetMonitoringDashWeb.DashboardLive.Components.ScenarioBanner do
  @moduledoc """
  Active demo scenario notice and reset action.
  """

  use Phoenix.Component

  import AssetMonitoringDashWeb.CoreComponents, only: [icon: 1]

  alias AssetMonitoringDashWeb.UI.Button

  attr :scenario_count, :integer, required: true

  def render(assigns) do
    ~H"""
    <div
      :if={@scenario_count > 0}
      id="active-scenario-banner"
      class="mt-5 flex flex-col gap-3 rounded-app border border-app-warn/25 bg-app-warn/10 p-4 shadow-app-panel sm:flex-row sm:items-center sm:justify-between"
    >
      <div class="flex min-w-0 items-center gap-3">
        <span class="grid size-9 shrink-0 place-items-center rounded-full bg-app-warn/15 text-app-warn ring-1 ring-app-warn/25">
          <.icon name="hero-bolt" class="size-4" />
        </span>
        <div class="min-w-0">
          <p class="text-sm font-semibold text-app-fg">Demo scenario active</p>
          <p id="active-scenario-count" class="mt-1 font-mono text-xs text-app-muted">
            {scenario_count_label(@scenario_count)}
          </p>
        </div>
      </div>

      <Button.render
        id="reset-asset-scenarios"
        phx-click="reset_asset_scenarios"
        class="h-9 shrink-0 px-4"
      >
        Reset scenarios
      </Button.render>
    </div>
    """
  end

  defp scenario_count_label(1), do: "1 active scenario"
  defp scenario_count_label(count), do: "#{count} active scenarios"
end
