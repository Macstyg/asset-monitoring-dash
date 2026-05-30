defmodule AssetMonitoringDashWeb.DashboardComponents.ReviewWorkflowPanel do
  @moduledoc """
  Product component that separates system recommendation from operator state.
  """

  use Phoenix.Component

  alias AssetMonitoringDashWeb.UI.Badge
  alias AssetMonitoringDashWeb.UI.Card

  attr :recommendation, :map, required: true
  attr :review_state, :map, required: true

  def render(assigns) do
    ~H"""
    <Card.surface
      id="review-workflow-panel"
      variant={:inset}
      class="mt-4"
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
          <div id="risk-recommendation-reasons" class="mt-3 space-y-2">
            <Card.surface
              :for={reason <- @recommendation.reasons}
              id={"risk-recommendation-reason-#{reason.id}"}
              tag="div"
              variant={:subtle}
              padding="px-3 py-2"
              class="bg-app-bg"
            >
              <p class="text-xs font-semibold text-app-fg">{reason.label}</p>
              <p class="mt-1 text-xs leading-5 text-app-muted">{reason.detail}</p>
            </Card.surface>
          </div>
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
    </Card.surface>
    """
  end
end
