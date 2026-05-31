defmodule AssetMonitoringDashWeb.AssetLive.Components.DecisionRail do
  @moduledoc """
  Right-rail workflow for scenario checks and operator decisions.
  """

  use Phoenix.Component

  alias AssetMonitoringDashWeb.AssetLive.Components.InvestigationBrief
  alias AssetMonitoringDashWeb.AssetLive.Components.ReviewActionForm
  alias AssetMonitoringDashWeb.AssetLive.Components.ScenarioControls

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
        active_scenario={@active_scenario}
        asset_shocked?={@asset_shocked?}
        scenario_options={@scenario_options}
      />

      <ReviewActionForm.render
        form={@review_action_form}
        reason_options={@reason_options}
        reviewed={@reviewed}
        escalated={@escalated}
      />
    </aside>
    """
  end
end
