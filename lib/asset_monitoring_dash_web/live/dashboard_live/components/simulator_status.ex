defmodule AssetMonitoringDashWeb.DashboardLive.Components.SimulatorStatus do
  @moduledoc """
  Runtime status panel for the supervised demo simulator.
  """

  use Phoenix.Component

  import AssetMonitoringDashWeb.CoreComponents, only: [icon: 1]

  alias AssetMonitoringDashWeb.UI.Button
  alias AssetMonitoringDashWeb.UI.Card
  alias AssetMonitoringDashWeb.UI.Panel
  alias AssetMonitoringDashWeb.UI.SectionHeader

  attr :scenario_count, :integer, required: true
  attr :status, :map, required: true

  def render(assigns) do
    ~H"""
    <Panel.render id="simulator-status">
      <SectionHeader.render
        title="Simulator"
        description="Supervised runtime driving live activity and scenario ticks."
      >
        <:actions>
          <span
            id="simulator-state"
            class={[
              "rounded-full px-3 py-1 text-xs font-medium ring-1 ring-inset",
              state_class(@status)
            ]}
          >
            {state_label(@status)}
          </span>
        </:actions>
      </SectionHeader.render>

      <div class="mt-5 grid gap-3 sm:grid-cols-2 xl:grid-cols-5">
        <Card.surface tag="div" variant={:inset}>
          <p class="font-mono text-xs uppercase tracking-[0.12em] text-app-muted">Ticks</p>
          <p id="simulator-tick-index" class="mt-2 font-mono text-lg font-semibold text-app-fg">
            {@status.tick_index}
          </p>
        </Card.surface>

        <Card.surface tag="div" variant={:inset}>
          <p class="font-mono text-xs uppercase tracking-[0.12em] text-app-muted">Next Event</p>
          <p id="simulator-next-event-index" class="mt-2 font-mono text-lg font-semibold text-app-fg">
            {@status.next_event_index}
          </p>
        </Card.surface>

        <Card.surface tag="div" variant={:inset}>
          <p class="font-mono text-xs uppercase tracking-[0.12em] text-app-muted">Scenario Cadence</p>
          <p id="simulator-scenario-cadence" class="mt-2 font-mono text-sm font-semibold text-app-fg">
            {cadence_label(@status.scenario_every)}
          </p>
        </Card.surface>

        <Card.surface tag="div" variant={:inset}>
          <p class="font-mono text-xs uppercase tracking-[0.12em] text-app-muted">Scenario Cap</p>
          <p id="simulator-scenario-cap" class="mt-2 font-mono text-sm font-semibold text-app-fg">
            {@status.max_active_scenarios}
          </p>
        </Card.surface>

        <Card.surface tag="div" variant={:inset}>
          <p class="font-mono text-xs uppercase tracking-[0.12em] text-app-muted">Active Scenarios</p>
          <p id="simulator-active-scenarios" class="mt-2 font-mono text-sm font-semibold text-app-fg">
            {@scenario_count} / {@status.max_active_scenarios}
          </p>
        </Card.surface>
      </div>

      <div class="mt-5 flex flex-wrap gap-2">
        <Button.render
          id="simulator-run-tick"
          phx-click="push_demo_event"
          disabled={!@status.running?}
          class="h-9 gap-2 rounded-app px-3"
        >
          <.icon name="hero-bolt" class="size-3.5" /> Run tick now
        </Button.render>

        <Button.render
          id="simulator-toggle"
          phx-click="toggle_event_feed"
          disabled={!@status.running?}
          class="h-9 gap-2 rounded-app px-3"
        >
          <.icon name={toggle_icon(@status)} class="size-3.5" />
          {toggle_label(@status)}
        </Button.render>
      </div>
    </Panel.render>
    """
  end

  defp state_label(%{running?: false}), do: "Offline"
  defp state_label(%{paused?: true}), do: "Paused"
  defp state_label(_status), do: "Streaming"

  defp state_class(%{running?: false}), do: "bg-app-bg text-app-muted ring-app-border"
  defp state_class(%{paused?: true}), do: "bg-app-warn/10 text-app-warn ring-app-warn/25"
  defp state_class(_status), do: "bg-app-accent/10 text-app-accent ring-app-accent/20"

  defp cadence_label(value) when is_integer(value), do: "every #{value} ticks"
  defp cadence_label(_value), do: "manual"

  defp toggle_icon(%{paused?: true}), do: "hero-play"
  defp toggle_icon(_status), do: "hero-pause"

  defp toggle_label(%{paused?: true}), do: "Resume process"
  defp toggle_label(_status), do: "Pause process"
end
