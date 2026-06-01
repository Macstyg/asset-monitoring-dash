defmodule AssetMonitoringDashWeb.DashboardLive.Components.SimulatorStatus do
  @moduledoc """
  Runtime status panel for the supervised demo simulator.
  """

  use Phoenix.Component

  import AssetMonitoringDashWeb.CoreComponents, only: [icon: 1]

  alias AssetMonitoringDashWeb.UI.Badge
  alias AssetMonitoringDashWeb.UI.Button
  alias AssetMonitoringDashWeb.UI.Card
  alias AssetMonitoringDashWeb.UI.Panel
  alias AssetMonitoringDashWeb.UI.SectionHeader

  attr :last_action, :map, default: nil
  attr :scenario_count, :integer, required: true
  attr :scenario_summary, :list, default: []
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

      <div
        id="simulator-scenario-summary"
        class={[
          "mt-4 rounded-app border border-app-border bg-app-bg/60 p-3",
          @scenario_summary == [] && "hidden"
        ]}
      >
        <p class="font-mono text-xs font-semibold uppercase tracking-[0.12em] text-app-muted">
          Active scenario mix
        </p>
        <div class="mt-2 flex flex-wrap gap-2">
          <span
            :for={scenario <- @scenario_summary}
            id={"simulator-scenario-count-#{scenario.id}"}
            class="inline-flex items-center gap-2 rounded-full bg-app-surface-2 px-3 py-1 text-xs font-semibold text-app-fg ring-1 ring-app-border"
            title={scenario.description}
          >
            <span class="font-mono text-app-muted">{scenario.count}</span>
            {scenario.label}
          </span>
        </div>
      </div>

      <div
        id="simulator-runtime-path"
        class="mt-4 grid gap-2 rounded-app border border-app-border bg-app-bg/60 p-3 sm:grid-cols-3"
      >
        <div class="flex items-start gap-3">
          <span class="mt-0.5 grid size-7 shrink-0 place-items-center rounded-app bg-app-accent/10 text-app-accent ring-1 ring-app-accent/20">
            <.icon name="hero-cpu-chip" class="size-4" />
          </span>
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.12em] text-app-muted">Process</p>
            <p class="mt-1 text-sm font-medium text-app-fg">Supervised GenServer</p>
          </div>
        </div>

        <div class="flex items-start gap-3">
          <span class="mt-0.5 grid size-7 shrink-0 place-items-center rounded-app bg-app-warn/10 text-app-warn ring-1 ring-app-warn/20">
            <.icon name="hero-circle-stack" class="size-4" />
          </span>
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.12em] text-app-muted">Writes</p>
            <p class="mt-1 text-sm font-medium text-app-fg">Scenarios, events, audit log</p>
          </div>
        </div>

        <div class="flex items-start gap-3">
          <span class="mt-0.5 grid size-7 shrink-0 place-items-center rounded-app bg-app-success/10 text-app-success ring-1 ring-app-success/20">
            <.icon name="hero-signal" class="size-4" />
          </span>
          <div>
            <p class="text-xs font-semibold uppercase tracking-[0.12em] text-app-muted">Broadcasts</p>
            <p class="mt-1 text-sm font-medium text-app-fg">Dashboard and detail refresh</p>
          </div>
        </div>
      </div>

      <div
        id="simulator-last-action"
        class="mt-4 rounded-app border border-app-border bg-app-surface-2/70 p-4"
      >
        <div class="flex flex-wrap items-center justify-between gap-3">
          <div>
            <p class="font-mono text-xs font-semibold uppercase tracking-[0.12em] text-app-muted">
              Last simulator action
            </p>
            <p class="mt-1 text-sm font-semibold text-app-fg">
              {last_action_title(@last_action)}
            </p>
          </div>

          <div class="flex flex-wrap items-center gap-2">
            <Badge.render
              :if={@last_action}
              id="simulator-last-action-kind"
              label={@last_action.label}
              tone={@last_action.tone}
            />
            <span
              id="simulator-last-action-time"
              class="rounded-full px-3 py-1 font-mono text-xs font-semibold text-app-muted ring-1 ring-app-border"
            >
              {last_action_time(@last_action)}
            </span>
          </div>
        </div>

        <p
          id="simulator-last-action-detail"
          class="mt-3 max-w-4xl text-sm leading-6 text-app-muted"
        >
          {last_action_detail(@last_action)}
        </p>

        <p
          :if={last_action_context(@last_action)}
          id="simulator-last-action-context"
          class="mt-2 font-mono text-xs font-semibold uppercase tracking-[0.12em] text-app-muted"
        >
          {last_action_context(@last_action)}
        </p>
      </div>

      <div class="mt-5 flex flex-wrap gap-2">
        <Button.render
          id="simulator-run-event-tick"
          phx-click="run_event_tick"
          disabled={!@status.running?}
          class="h-9 gap-2 rounded-app px-3"
          title="Emit one persisted activity event without changing asset state."
        >
          <.icon name="hero-bolt" class="size-3.5" /> Run event tick
        </Button.render>

        <Button.render
          id="simulator-run-scenario-tick"
          phx-click="run_scenario_tick"
          disabled={scenario_tick_disabled?(@status, @scenario_count)}
          class="h-9 gap-2 rounded-app px-3"
          title={scenario_tick_title(@status, @scenario_count)}
        >
          <.icon name="hero-sparkles" class="size-3.5" /> Run scenario tick
        </Button.render>

        <Button.render
          id="simulator-toggle"
          phx-click="toggle_simulator_process"
          disabled={!@status.running?}
          class="h-9 gap-2 rounded-app px-3"
        >
          <.icon name={toggle_icon(@status)} class="size-3.5" />
          {toggle_label(@status)}
        </Button.render>

        <Button.render
          id="simulator-reset-runtime"
          phx-click="reset_demo_runtime"
          class="h-9 gap-2 rounded-app px-3"
        >
          <.icon name="hero-arrow-path" class="size-3.5" /> Reset runtime
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

  defp scenario_tick_disabled?(%{running?: false}, _scenario_count), do: true

  defp scenario_tick_disabled?(status, scenario_count) do
    scenario_cap_reached?(status, scenario_count)
  end

  defp scenario_tick_title(status, scenario_count) do
    case scenario_cap_reached?(status, scenario_count) do
      true -> "Scenario cap reached. Reset runtime before applying another scenario."
      false -> "Apply the next persisted scenario overlay to a candidate asset."
    end
  end

  defp scenario_cap_reached?(%{max_active_scenarios: max_active_scenarios}, scenario_count)
       when is_integer(max_active_scenarios) do
    scenario_count >= max_active_scenarios
  end

  defp scenario_cap_reached?(_status, _scenario_count), do: false

  defp cadence_label(value) when is_integer(value), do: "every #{value} ticks"
  defp cadence_label(_value), do: "manual"

  defp last_action_title(nil), do: "Waiting for the next tick"
  defp last_action_title(%{title: title}), do: title

  defp last_action_detail(nil) do
    "Run an event tick to append operational activity, or run a scenario tick to mutate a candidate asset."
  end

  defp last_action_detail(%{detail: detail}), do: detail

  defp last_action_time(nil), do: "not run"
  defp last_action_time(%{timestamp: timestamp}), do: timestamp

  defp last_action_context(nil), do: nil
  defp last_action_context(%{context: nil}), do: nil
  defp last_action_context(%{context: context}), do: context

  defp toggle_icon(%{paused?: true}), do: "hero-play"
  defp toggle_icon(_status), do: "hero-pause"

  defp toggle_label(%{paused?: true}), do: "Resume process"
  defp toggle_label(_status), do: "Pause process"
end
