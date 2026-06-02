defmodule AssetMonitoringDashWeb.AssetLive.Components.DemoStoryContext do
  @moduledoc """
  Presenter-mode context for the asset inspection step of the demo story.
  """

  use AssetMonitoringDashWeb, :html

  alias AssetMonitoringDashWeb.UI.Badge
  alias AssetMonitoringDashWeb.UI.Button
  alias AssetMonitoringDashWeb.UI.Panel

  attr :activity_path, :string, required: true
  attr :completed?, :boolean, required: true
  attr :return_to, :string, required: true
  attr :review_state, :map, required: true

  def render(assigns) do
    ~H"""
    <Panel.render id="asset-demo-story" class="p-0">
      <div class="grid gap-px bg-app-border lg:grid-cols-[minmax(0,1fr)_auto]">
        <div class="min-w-0 bg-app-surface p-5">
          <div class="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
            <div class="min-w-0">
              <p class="font-mono text-xs font-semibold uppercase tracking-[0.12em] text-app-muted">
                Demo story
              </p>
              <h2 class="mt-2 text-base font-semibold text-app-fg">
                Inspect the impacted asset, then close the review loop.
              </h2>
              <p id="asset-demo-story-detail" class="mt-2 max-w-3xl text-sm leading-6 text-app-muted">
                The dashboard showed portfolio-level pressure. This page explains the affected
                position, records the operator decision, and exposes the persisted audit trail.
              </p>
            </div>

            <div class="flex shrink-0 flex-wrap items-center gap-2">
              <Badge.render
                id="asset-demo-story-state"
                label={story_state_label(@completed?)}
                tone={story_state_tone(@completed?)}
              />
              <Badge.render
                id="asset-demo-review-state"
                label={@review_state.label}
                tone={@review_state.tone}
              />
            </div>
          </div>

          <ol class="mt-5 grid gap-2 sm:grid-cols-3">
            <.story_step
              id="asset-demo-step-inspect"
              label="Inspect"
              state="Done"
              tone={:positive}
              detail="Asset risk drivers are visible."
            />
            <.story_step
              id="asset-demo-step-review"
              label="Review"
              state={review_step_label(@completed?)}
              tone={review_step_tone(@completed?)}
              detail="Operator state is stored separately."
            />
            <.story_step
              id="asset-demo-step-audit"
              label="Audit"
              state={audit_step_label(@completed?)}
              tone={review_step_tone(@completed?)}
              detail="History is available on Activity."
            />
          </ol>
        </div>

        <div class="flex flex-col gap-2 bg-app-surface p-5 sm:flex-row lg:min-w-72 lg:flex-col">
          <.link
            id="asset-demo-open-audit"
            patch={@activity_path}
            class={[
              "inline-flex h-10 items-center justify-center gap-2 rounded-app border px-3 text-sm font-semibold transition",
              audit_link_class(@completed?)
            ]}
          >
            <.icon name="hero-clock" class="size-4" /> Open audit trail
          </.link>

          <.link
            id="asset-demo-back-dashboard"
            navigate={@return_to}
            class="inline-flex h-10 items-center justify-center gap-2 rounded-app border border-app-border bg-app-surface-2 px-3 text-sm font-semibold text-app-muted transition hover:border-app-accent/50 hover:text-app-fg"
          >
            <.icon name="hero-arrow-left" class="size-4" /> Back to dashboard
          </.link>

          <Button.render
            id="asset-demo-reset-replay"
            phx-click="reset_demo_runtime_and_return"
            class="h-10 gap-2 rounded-app px-3 text-sm"
          >
            <.icon name="hero-arrow-path" class="size-4" /> Reset and replay
          </Button.render>
        </div>
      </div>
    </Panel.render>
    """
  end

  attr :detail, :string, required: true
  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :state, :string, required: true
  attr :tone, :atom, required: true

  defp story_step(assigns) do
    ~H"""
    <li id={@id} class="rounded-app border border-app-border bg-app-bg px-3 py-3">
      <div class="flex items-center justify-between gap-3">
        <p class="text-sm font-semibold text-app-fg">{@label}</p>
        <span class={[
          "rounded-full px-2 py-0.5 font-mono text-[0.68rem] font-semibold uppercase tracking-[0.1em] ring-1 ring-inset",
          step_state_class(@tone)
        ]}>
          {@state}
        </span>
      </div>
      <p class="mt-2 text-xs leading-5 text-app-muted">{@detail}</p>
    </li>
    """
  end

  defp story_state_label(true), do: "Loop closed"
  defp story_state_label(false), do: "Inspection phase"

  defp story_state_tone(true), do: :success
  defp story_state_tone(false), do: :info

  defp review_step_label(true), do: "Done"
  defp review_step_label(false), do: "Pending"

  defp audit_step_label(true), do: "Ready"
  defp audit_step_label(false), do: "Pending"

  defp review_step_tone(true), do: :positive
  defp review_step_tone(false), do: :neutral

  defp audit_link_class(true), do: "border-app-accent/35 bg-app-accent/10 text-app-accent"
  defp audit_link_class(false), do: "border-app-border bg-app-surface-2 text-app-muted"

  defp step_state_class(:positive), do: "bg-app-accent/10 text-app-accent ring-app-accent/20"
  defp step_state_class(:neutral), do: "bg-app-surface-2 text-app-muted ring-app-border"
end
