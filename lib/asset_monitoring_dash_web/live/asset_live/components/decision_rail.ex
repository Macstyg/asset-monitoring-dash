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
  attr :escalated, :boolean, required: true
  attr :health_factor, :string, required: true
  attr :reason_options, :list, required: true
  attr :review_action_form, :any, required: true
  attr :review_state, :map, required: true
  attr :reviewed, :boolean, required: true
  attr :risk_recommendation, :map, required: true

  def render(assigns) do
    ~H"""
    <aside id="asset-decision-rail" class="grid min-w-0 gap-4 xl:sticky xl:top-6">
      <InvestigationBrief.render
        asset={@asset}
        health_factor={@health_factor}
        risk_recommendation={@risk_recommendation}
        review_state={@review_state}
      />

      <ScenarioControls.render asset_shocked?={@asset_shocked?} />

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
