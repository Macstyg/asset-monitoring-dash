defmodule AssetMonitoringDashWeb.AssetLive.Components.InvestigationBrief do
  @moduledoc """
  Triage summary for the asset detail page.
  """

  use Phoenix.Component

  alias AssetMonitoringDashWeb.Formatters
  alias AssetMonitoringDashWeb.UI.Badge
  alias AssetMonitoringDashWeb.UI.Card

  attr :asset, :map, required: true
  attr :health_factor, :string, required: true
  attr :risk_recommendation, :map, required: true
  attr :review_state, :map, required: true

  def render(assigns) do
    ~H"""
    <Card.surface id="investigation-brief">
      <div class="flex flex-col gap-3 lg:flex-row lg:items-start lg:justify-between">
        <div>
          <h2 class="text-base font-semibold text-app-fg">Investigation brief</h2>
          <p id="investigation-primary-question" class="mt-1 text-sm leading-6 text-app-muted">
            {primary_question(@risk_recommendation.id)}
          </p>
        </div>

        <div class="flex flex-wrap items-center gap-2">
          <Badge.render
            id="investigation-recommendation"
            label={@risk_recommendation.label}
            tone={@risk_recommendation.tone}
          />
          <Badge.render
            id="investigation-review-state"
            label={@review_state.label}
            tone={@review_state.tone}
          />
        </div>
      </div>

      <div class="mt-5 grid gap-3 md:grid-cols-3">
        <div class="border-t border-app-border pt-3 md:border-l md:border-t-0 md:pl-4 md:pt-0">
          <p class="font-mono text-xs uppercase tracking-[0.12em] text-app-muted">
            Next step
          </p>
          <p id="investigation-next-step" class="mt-2 text-sm font-semibold leading-6 text-app-fg">
            {next_step(@risk_recommendation, @review_state)}
          </p>
        </div>

        <div class="border-t border-app-border pt-3 md:border-l md:border-t-0 md:pl-4 md:pt-0">
          <p class="font-mono text-xs uppercase tracking-[0.12em] text-app-muted">
            Collateral buffer
          </p>
          <p id="investigation-buffer" class="mt-2 font-mono text-sm font-semibold text-app-fg">
            {Formatters.ltv(@asset.ltv_percent)} LTV · {@health_factor} health
          </p>
        </div>

        <div class="border-t border-app-border pt-3 md:border-l md:border-t-0 md:pl-4 md:pt-0">
          <p class="font-mono text-xs uppercase tracking-[0.12em] text-app-muted">
            Data confidence
          </p>
          <p id="investigation-data-confidence" class="mt-2 text-sm font-semibold text-app-fg">
            {@asset.oracle_status} oracle · {@asset.liquidity_status} liquidity
          </p>
        </div>
      </div>
    </Card.surface>
    """
  end

  defp primary_question(:liquidation_candidate), do: "Can this collateral be escalated safely?"
  defp primary_question(:manual_review), do: "Does this position need analyst intervention?"
  defp primary_question(:watch), do: "Should this position stay on the active watchlist?"
  defp primary_question(:clear), do: "Can this position remain in normal monitoring?"
  defp primary_question(_recommendation), do: "What should the operator verify next?"

  defp next_step(_recommendation, %{id: :reviewed}) do
    "Reviewed. Continue monitoring for price, oracle, or liquidity changes."
  end

  defp next_step(_recommendation, %{id: :escalated}) do
    "Escalated. Keep the position in the operator queue until follow-up is complete."
  end

  defp next_step(%{detail: detail}, _review_state), do: detail
end
