defmodule AssetMonitoringDashWeb.DashboardLive.Components.DemoWalkthrough do
  @moduledoc """
  Guided demo path for the dashboard scenario workflow.
  """

  use Phoenix.Component

  import AssetMonitoringDashWeb.CoreComponents, only: [icon: 1]

  alias AssetMonitoringDashWeb.UI.Button
  alias AssetMonitoringDashWeb.UI.Card
  alias AssetMonitoringDashWeb.UI.Panel
  alias AssetMonitoringDashWeb.UI.SectionHeader

  attr :active_asset, :map, default: nil
  attr :active_asset_path, :string, default: nil
  attr :last_action, :map, default: nil
  attr :scenario_count, :integer, required: true
  attr :status, :map, required: true

  def render(assigns) do
    ~H"""
    <Panel.render id="demo-walkthrough" class="overflow-hidden p-0">
      <div class="border-b border-app-border p-5">
        <SectionHeader.render
          title="Demo story"
          description="A short walkthrough for showing how persisted data, simulator events, scenario overlays, and analyst review connect."
        >
          <:actions>
            <span
              id="demo-story-state"
              class={[
                "rounded-full px-3 py-1 font-mono text-xs font-semibold ring-1 ring-inset",
                story_state_class(@scenario_count)
              ]}
            >
              {story_state_label(@scenario_count)}
            </span>
          </:actions>
        </SectionHeader.render>
      </div>

      <ol class="grid gap-px bg-app-border lg:grid-cols-5">
        <.story_step
          id="demo-step-reset"
          icon="hero-arrow-path"
          index="01"
          status={reset_status(@scenario_count)}
          title="Start clean"
          description="Reset mutable state so the dashboard begins from the seeded database baseline."
        >
          <Button.render
            id="demo-reset-runtime"
            phx-click="reset_demo_runtime"
            class="mt-4 h-9 gap-2 rounded-app px-3"
          >
            <.icon name="hero-arrow-path" class="size-3.5" /> Reset runtime
          </Button.render>
        </.story_step>

        <.story_step
          id="demo-step-scenario"
          icon="hero-sparkles"
          index="02"
          status={scenario_status(@scenario_count)}
          title="Apply pressure"
          description="Run a scenario tick to persist a shock, review reset, and event trail for one candidate asset."
        >
          <Button.render
            id="demo-run-scenario"
            phx-click="run_scenario_tick"
            disabled={scenario_tick_disabled?(@status, @scenario_count)}
            class="mt-4 h-9 gap-2 rounded-app px-3"
            title={scenario_tick_title(@status, @scenario_count)}
          >
            <.icon name="hero-bolt" class="size-3.5" /> Run scenario tick
          </Button.render>
        </.story_step>

        <.story_step
          id="demo-step-dashboard"
          icon="hero-chart-bar-square"
          index="03"
          status={dashboard_status(@scenario_count)}
          title="Read movement"
          description="Use cards, charts, and the activity stream to explain what changed at portfolio level."
        >
          <div class="mt-4 flex flex-wrap gap-2">
            <a
              id="demo-open-analytics"
              href="#dashboard-analytics"
              class="inline-flex h-9 items-center gap-2 rounded-app border border-app-border bg-app-surface-2 px-3 text-xs font-semibold text-app-muted transition hover:border-app-accent/50 hover:text-app-fg"
            >
              <.icon name="hero-chart-pie" class="size-3.5" /> Analytics
            </a>
            <a
              id="demo-open-operations"
              href="#operations-telemetry"
              class="inline-flex h-9 items-center gap-2 rounded-app border border-app-border bg-app-surface-2 px-3 text-xs font-semibold text-app-muted transition hover:border-app-accent/50 hover:text-app-fg"
            >
              <.icon name="hero-rss" class="size-3.5" /> Feed
            </a>
          </div>
        </.story_step>

        <.story_step
          id="demo-step-inspect"
          icon="hero-magnifying-glass"
          index="04"
          status={inspect_status(@active_asset)}
          title="Inspect asset"
          description="Open the impacted asset and connect portfolio movement to asset-level risk drivers."
        >
          <.link
            :if={@active_asset && @active_asset_path}
            id="demo-inspect-asset"
            navigate={@active_asset_path}
            class="mt-4 inline-flex h-9 max-w-full items-center gap-2 rounded-app border border-app-accent/35 bg-app-accent/10 px-3 text-xs font-semibold text-app-accent transition hover:border-app-accent"
          >
            <.icon name="hero-arrow-top-right-on-square" class="size-3.5" />
            <span class="truncate">{@active_asset.name}</span>
          </.link>
          <span
            :if={!@active_asset || !@active_asset_path}
            id="demo-inspect-asset-placeholder"
            class="mt-4 inline-flex h-9 items-center gap-2 rounded-app border border-app-border bg-app-surface-2 px-3 text-xs font-semibold text-app-muted"
          >
            <.icon name="hero-clock" class="size-3.5" /> Waiting for scenario
          </span>
        </.story_step>

        <.story_step
          id="demo-step-review"
          icon="hero-clipboard-document-check"
          index="05"
          status={review_status(@last_action)}
          title="Close the loop"
          description="Use the asset page to mark reviewed or escalate, then point to the persisted audit trail."
        >
          <p
            id="demo-review-last-action"
            class="mt-4 line-clamp-2 text-xs leading-5 text-app-muted"
          >
            {review_hint(@last_action)}
          </p>
        </.story_step>
      </ol>
    </Panel.render>
    """
  end

  attr :description, :string, required: true
  attr :icon, :string, required: true
  attr :id, :string, required: true
  attr :index, :string, required: true
  attr :status, :map, required: true
  attr :title, :string, required: true

  slot :inner_block

  defp story_step(assigns) do
    ~H"""
    <li id={@id} class="min-w-0 bg-app-surface p-5">
      <Card.surface tag="div" variant={:subtle} padding="p-0" class="border-0 bg-transparent">
        <div class="flex min-w-0 items-start gap-3">
          <span class={[
            "grid size-9 shrink-0 place-items-center rounded-app ring-1 ring-inset",
            step_icon_class(@status.tone)
          ]}>
            <.icon name={@icon} class="size-4" />
          </span>
          <div class="min-w-0">
            <div class="flex min-w-0 flex-wrap items-center gap-2">
              <span class="font-mono text-xs font-semibold uppercase tracking-[0.12em] text-app-muted">
                {@index}
              </span>
              <span class={[
                "rounded-full px-2 py-0.5 font-mono text-[0.68rem] font-semibold uppercase tracking-[0.1em] ring-1 ring-inset",
                step_badge_class(@status.tone)
              ]}>
                {@status.label}
              </span>
            </div>
            <h3 class="mt-3 text-sm font-semibold text-app-fg">{@title}</h3>
            <p class="mt-2 text-xs leading-5 text-app-muted">{@description}</p>
          </div>
        </div>

        {render_slot(@inner_block)}
      </Card.surface>
    </li>
    """
  end

  defp story_state_label(0), do: "Ready"
  defp story_state_label(count), do: "#{count} scenario#{plural_suffix(count)} active"

  defp story_state_class(0), do: "bg-app-accent/10 text-app-accent ring-app-accent/20"
  defp story_state_class(_count), do: "bg-app-warn/10 text-app-warn ring-app-warn/25"

  defp reset_status(0), do: %{label: "clean", tone: :positive}
  defp reset_status(_count), do: %{label: "reset", tone: :warning}

  defp scenario_status(0), do: %{label: "next", tone: :neutral}
  defp scenario_status(_count), do: %{label: "applied", tone: :warning}

  defp dashboard_status(0), do: %{label: "baseline", tone: :neutral}
  defp dashboard_status(_count), do: %{label: "changed", tone: :positive}

  defp inspect_status(nil), do: %{label: "waiting", tone: :neutral}
  defp inspect_status(_asset), do: %{label: "ready", tone: :positive}

  defp review_status(%{label: label}) when label in ["Scenario tick", "Event tick"] do
    %{label: "pending", tone: :neutral}
  end

  defp review_status(%{label: _label}), do: %{label: "logged", tone: :positive}
  defp review_status(nil), do: %{label: "later", tone: :neutral}

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

  defp review_hint(nil),
    do: "After inspection, record a review decision from the asset detail page."

  defp review_hint(%{detail: detail}), do: detail

  defp step_icon_class(:positive), do: "bg-app-accent/10 text-app-accent ring-app-accent/20"
  defp step_icon_class(:warning), do: "bg-app-warn/10 text-app-warn ring-app-warn/25"
  defp step_icon_class(:neutral), do: "bg-app-surface-2 text-app-muted ring-app-border"

  defp step_badge_class(:positive), do: "bg-app-accent/10 text-app-accent ring-app-accent/20"
  defp step_badge_class(:warning), do: "bg-app-warn/10 text-app-warn ring-app-warn/25"
  defp step_badge_class(:neutral), do: "bg-app-surface-2 text-app-muted ring-app-border"

  defp plural_suffix(1), do: ""
  defp plural_suffix(_count), do: "s"
end
