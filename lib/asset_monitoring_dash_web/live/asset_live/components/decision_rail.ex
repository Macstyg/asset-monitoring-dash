defmodule AssetMonitoringDashWeb.AssetLive.Components.DecisionRail do
  @moduledoc """
  Right-rail workflow for scenario checks and operator decisions.
  """

  use Phoenix.Component

  alias AssetMonitoringDashWeb.AssetLive.Components.InvestigationBrief
  alias AssetMonitoringDashWeb.AssetLive.Components.ReviewActionForm
  alias AssetMonitoringDashWeb.AssetLive.Components.ScenarioControls
  alias AssetMonitoringDashWeb.UI.Card

  attr :asset, :map, required: true
  attr :asset_shocked?, :boolean, required: true
  attr :active_scenario, :map, default: nil
  attr :escalated, :boolean, required: true
  attr :health_factor, :string, required: true
  attr :reason_options, :list, required: true
  attr :review_action_form, :any, required: true
  attr :review_state, :map, required: true
  attr :reviewed, :boolean, required: true
  attr :risk_recommendation, :map, required: true
  attr :operator_controls_enabled?, :boolean, default: true
  attr :scenario_options, :list, required: true

  def render(assigns) do
    ~H"""
    <aside id="asset-decision-rail" class="grid min-w-0 gap-4 xl:sticky xl:top-6">
      <InvestigationBrief.render
        asset={@asset}
        health_factor={@health_factor}
        risk_recommendation={@risk_recommendation}
        review_state={@review_state}
      />

      <ScenarioControls.render
        :if={@operator_controls_enabled?}
        active_scenario={@active_scenario}
        asset_shocked?={@asset_shocked?}
        scenario_options={@scenario_options}
      />

      <ReviewActionForm.render
        :if={@operator_controls_enabled?}
        form={@review_action_form}
        reason_options={@reason_options}
        reviewed={@reviewed}
        escalated={@escalated}
      />

      <Card.surface :if={!@operator_controls_enabled?} id="asset-read-only-actions" variant={:inset}>
        <p class="font-mono text-xs font-semibold uppercase tracking-[0.12em] text-app-muted">
          View-only mode
        </p>
        <h3 class="mt-2 text-sm font-semibold text-app-fg">
          Operator actions require an account
        </h3>
        <p class="mt-2 text-sm leading-6 text-app-muted">
          Scenario controls and review decisions are hidden on the public asset page. Sign in to
          run demo shocks, mark reviews, or escalate this position.
        </p>
        <div class="mt-4 flex flex-wrap gap-2">
          <.link
            id="asset-read-only-login-link"
            navigate="/users/log-in"
            class="inline-flex h-9 items-center justify-center rounded-app border border-app-accent/35 bg-app-accent/10 px-3 text-xs font-semibold text-app-accent transition hover:border-app-accent hover:bg-app-accent/15"
          >
            Log in
          </.link>
          <.link
            id="asset-read-only-register-link"
            navigate="/users/register"
            class="inline-flex h-9 items-center justify-center rounded-app border border-app-border bg-app-surface-2 px-3 text-xs font-semibold text-app-muted transition hover:border-app-accent/40 hover:text-app-fg"
          >
            Register
          </.link>
        </div>
      </Card.surface>
    </aside>
    """
  end
end
