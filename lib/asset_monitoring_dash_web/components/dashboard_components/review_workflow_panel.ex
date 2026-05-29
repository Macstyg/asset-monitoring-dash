defmodule AssetMonitoringDashWeb.DashboardComponents.ReviewWorkflowPanel do
  @moduledoc """
  Product component that separates system recommendation from operator state.
  """

  use Phoenix.Component

  alias AssetMonitoringDashWeb.UI.Badge

  attr :recommendation, :map, required: true
  attr :review_state, :map, required: true

  def render(assigns) do
    ~H"""
    <div
      id="review-workflow-panel"
      class="mt-4 rounded-app border border-app-border bg-app-surface-2 p-3"
    >
      <div class="grid gap-3 sm:grid-cols-2">
        <div>
          <p class="font-mono text-xs uppercase tracking-[0.12em] text-app-muted">
            System recommendation
          </p>
          <div id="risk-recommendation-label" class="mt-2">
            <Badge.render label={@recommendation.label} tone={@recommendation.tone} />
          </div>
          <p id="risk-recommendation-detail" class="mt-2 text-xs leading-5 text-app-muted">
            {@recommendation.detail}
          </p>
        </div>

        <div>
          <p class="font-mono text-xs uppercase tracking-[0.12em] text-app-muted">
            Operator state
          </p>
          <div id="operator-review-state-label" class="mt-2">
            <Badge.render label={@review_state.label} tone={@review_state.tone} />
          </div>
          <p id="operator-review-state-detail" class="mt-2 text-xs leading-5 text-app-muted">
            {@review_state.detail}
          </p>
        </div>
      </div>
    </div>
    """
  end
end
