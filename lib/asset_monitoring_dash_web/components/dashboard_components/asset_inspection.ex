defmodule AssetMonitoringDashWeb.DashboardComponents.AssetInspection do
  @moduledoc """
  Inspection panel for the currently selected collateral asset.
  """

  use Phoenix.Component

  alias AssetMonitoringDashWeb.DashboardComponents.RiskBadge
  alias AssetMonitoringDashWeb.Formatters
  alias AssetMonitoringDashWeb.UI.EntityIdentity

  attr :asset, :map, required: true
  attr :health_factor, :string, required: true

  slot :actions

  def render(assigns) do
    ~H"""
    <section
      id="asset-inspection"
      class="rounded-app border border-app-border bg-app-surface p-5 shadow-app-panel"
    >
      <div class="flex items-start justify-between gap-4">
        <div>
          <h2 class="text-base font-semibold text-app-fg">Selected asset</h2>
          <p class="mt-1 text-sm text-app-muted">Collateral position detail and review signals.</p>
        </div>
        <RiskBadge.render label={@asset.risk_band} />
      </div>

      <div :if={@actions != []} class="mt-4 flex flex-wrap gap-2">
        {render_slot(@actions)}
      </div>

      <EntityIdentity.render
        class="mt-5"
        name={@asset.name}
        caption={"#{@asset.chain} / #{@asset.ecosystem}"}
      />

      <dl class="mt-5 grid grid-cols-2 gap-3">
        <div class="rounded-app border border-app-border bg-app-surface-2 p-3">
          <dt class="font-mono text-xs uppercase tracking-[0.12em] text-app-muted">Value</dt>
          <dd class="mt-2 font-mono text-sm font-semibold tabular-nums text-app-fg">
            {Formatters.usd(@asset.current_value_usd)}
          </dd>
        </div>
        <div class="rounded-app border border-app-border bg-app-surface-2 p-3">
          <dt class="font-mono text-xs uppercase tracking-[0.12em] text-app-muted">Loan</dt>
          <dd class="mt-2 font-mono text-sm font-semibold tabular-nums text-app-fg">
            {Formatters.usd(@asset.loan_value_usd)}
          </dd>
        </div>
        <div class="rounded-app border border-app-border bg-app-surface-2 p-3">
          <dt class="font-mono text-xs uppercase tracking-[0.12em] text-app-muted">LTV</dt>
          <dd class="mt-2 font-mono text-sm font-semibold tabular-nums text-app-fg">
            {Formatters.ltv(@asset.ltv_percent)}
          </dd>
        </div>
        <div class="rounded-app border border-app-border bg-app-surface-2 p-3">
          <dt class="font-mono text-xs uppercase tracking-[0.12em] text-app-muted">Health</dt>
          <dd class="mt-2 font-mono text-sm font-semibold tabular-nums text-app-fg">
            {@health_factor}
          </dd>
        </div>
      </dl>

      <div class="mt-4 rounded-app border border-app-border bg-app-surface-2 p-3">
        <div class="flex items-center justify-between gap-3">
          <span class="font-mono text-xs uppercase tracking-[0.12em] text-app-muted">Risk score</span>
          <span class="font-mono text-sm font-semibold tabular-nums text-app-fg">
            {@asset.risk_score}/100
          </span>
        </div>
        <div class="mt-3 h-2 overflow-hidden rounded-full bg-app-bg">
          <div
            class="h-full rounded-full bg-linear-to-r from-app-accent via-app-warn to-app-danger"
            style={"width: #{@asset.risk_score}%"}
          >
          </div>
        </div>
      </div>
    </section>
    """
  end
end
