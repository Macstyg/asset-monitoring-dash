defmodule AssetMonitoringDashWeb.AssetLive.Components.RiskScorePanel do
  @moduledoc """
  Compact risk score meter for the inspected asset.
  """

  use Phoenix.Component

  alias AssetMonitoringDashWeb.UI.Card

  attr :score, :integer, required: true

  def render(assigns) do
    ~H"""
    <Card.surface variant={:inset} class="mt-4">
      <div class="flex items-center justify-between gap-3">
        <span class="font-mono text-xs uppercase tracking-[0.12em] text-app-muted">Risk score</span>
        <span class="font-mono text-sm font-semibold tabular-nums text-app-fg">
          {@score}/100
        </span>
      </div>
      <div class="mt-3 h-2 overflow-hidden rounded-full bg-app-bg">
        <div
          class="h-full rounded-full bg-linear-to-r from-app-accent via-app-warn to-app-danger"
          style={"width: #{@score}%"}
        >
        </div>
      </div>
    </Card.surface>
    """
  end
end
