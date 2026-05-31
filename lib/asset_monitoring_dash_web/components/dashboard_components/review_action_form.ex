defmodule AssetMonitoringDashWeb.DashboardComponents.ReviewActionForm do
  @moduledoc """
  Operator action form for recording asset review decisions.
  """

  use AssetMonitoringDashWeb, :html

  alias AssetMonitoringDashWeb.UI.Button
  alias AssetMonitoringDashWeb.UI.Card

  attr :escalated, :boolean, default: false
  attr :form, :any, required: true
  attr :reason_options, :list, required: true
  attr :reviewed, :boolean, default: false

  def render(assigns) do
    ~H"""
    <Card.surface id="review-action-panel">
      <div class="flex flex-col gap-1">
        <p class="font-mono text-xs font-semibold uppercase tracking-[0.12em] text-app-muted">
          Operator decision
        </p>
        <h2 class="text-base font-semibold text-app-fg">Review action</h2>
        <p class="text-sm leading-6 text-app-muted">
          Record the human decision separately from the system recommendation.
        </p>
      </div>

      <.form
        for={@form}
        id="review-action-form"
        phx-change="validate_review_action"
        phx-submit="submit_review_action"
        class="review-action-form mt-4 grid w-full gap-3"
      >
        <.input
          field={@form[:reason]}
          type="select"
          label="Review reason"
          options={@reason_options}
          class="h-11 w-full rounded-app border border-app-border bg-app-bg px-3 text-sm font-semibold text-app-fg outline-none transition hover:border-app-accent/35 focus:border-app-accent/50 focus:ring-2 focus:ring-app-accent/15"
        />
        <.input
          field={@form[:note]}
          type="textarea"
          label="Operator note"
          placeholder="Optional audit note"
          rows="3"
          maxlength="180"
          class="min-h-24 w-full resize-none rounded-app border border-app-border bg-app-bg px-3 py-2 text-sm leading-5 text-app-fg outline-none transition placeholder:text-app-muted hover:border-app-accent/35 focus:border-app-accent/50 focus:ring-2 focus:ring-app-accent/15"
        />

        <div class="flex flex-wrap gap-2 border-t border-app-border pt-3">
          <Button.render
            id="mark-asset-reviewed"
            type="submit"
            name="review_action[action]"
            value="reviewed"
            disabled={@reviewed}
            class="h-9 px-4"
          >
            Mark reviewed
          </Button.render>
          <Button.render
            id="escalate-asset-review"
            type="submit"
            name="review_action[action]"
            value="escalated"
            disabled={@escalated}
            class="h-9 px-4"
          >
            Escalate
          </Button.render>
        </div>
      </.form>
    </Card.surface>
    """
  end
end
