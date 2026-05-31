defmodule AssetMonitoringDashWeb.AssetLive.Components.RiskDrivers do
  @moduledoc """
  Human-readable risk explanation for the inspected asset.
  """

  use Phoenix.Component

  alias AssetMonitoringDashWeb.Formatters
  alias AssetMonitoringDashWeb.UI.Card

  attr :risk_explanation, :map, required: true

  def render(assigns) do
    ~H"""
    <Card.surface
      id="risk-explanation"
      variant={:inset}
      class="mt-4"
    >
      <p class="font-mono text-xs uppercase tracking-[0.12em] text-app-muted">Risk drivers</p>
      <p id="risk-explanation-headline" class="mt-2 text-sm font-semibold text-app-fg">
        {@risk_explanation.headline}
      </p>

      <div class="mt-3 space-y-3">
        <div
          :for={reason <- @risk_explanation.reasons}
          id={"risk-reason-#{reason.id}"}
          class="flex items-start justify-between gap-3 border-t border-app-border pt-3 first:border-t-0 first:pt-0"
        >
          <div class="min-w-0">
            <p class="text-sm font-semibold text-app-fg">{reason.label}</p>
            <p class="mt-1 text-xs leading-5 text-app-muted">{reason.detail}</p>
          </div>
          <span class={[
            "shrink-0 rounded-full px-2.5 py-1 font-mono text-xs font-semibold tabular-nums ring-1 ring-inset",
            reason_class(reason.tone)
          ]}>
            {format_reason_metric(reason.metric)}
          </span>
        </div>
      </div>
    </Card.surface>
    """
  end

  defp format_reason_metric({:decimal, value}), do: Formatters.decimal(value)
  defp format_reason_metric({:percent, value}), do: Formatters.ltv(value)
  defp format_reason_metric({:usd, value}), do: Formatters.usd(value)

  defp reason_class(:danger), do: "bg-app-danger/10 text-app-danger ring-app-danger/25"
  defp reason_class(:warning), do: "bg-app-warn/10 text-app-warn ring-app-warn/25"
  defp reason_class(:success), do: "bg-app-accent/10 text-app-accent ring-app-accent/20"
  defp reason_class(:neutral), do: "bg-app-bg text-app-muted ring-app-border"
end
