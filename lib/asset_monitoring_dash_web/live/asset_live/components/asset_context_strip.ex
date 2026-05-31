defmodule AssetMonitoringDashWeb.AssetLive.Components.AssetContextStrip do
  @moduledoc """
  Compact identity and signal summary for an inspected asset.
  """

  use Phoenix.Component

  alias AssetMonitoringDashWeb.Formatters
  alias AssetMonitoringDashWeb.UI.Badge
  alias AssetMonitoringDashWeb.UI.Card

  attr :asset, :map, required: true

  def render(assigns) do
    ~H"""
    <section
      id="asset-context-strip"
      aria-label="Asset context"
      class="grid min-w-0 gap-3 sm:grid-cols-2 xl:grid-cols-4"
    >
      <Card.surface padding="px-4 py-3" variant={:subtle}>
        <div class="flex min-w-0 items-center justify-between gap-3 xl:block">
          <div class="min-w-0">
            <p class="font-mono text-xs font-semibold uppercase tracking-[0.12em] text-app-muted">
              Chain / game
            </p>
            <p id="asset-context-chain" class="mt-2 truncate text-sm font-semibold text-app-fg">
              {@asset.chain}
            </p>
          </div>
          <p id="asset-context-game" class="mt-1 truncate font-mono text-xs text-app-muted">
            {@asset.ecosystem}
          </p>
        </div>
      </Card.surface>

      <Card.surface padding="px-4 py-3" variant={:subtle}>
        <div class="flex min-w-0 items-center justify-between gap-3 xl:block">
          <div class="min-w-0">
            <p class="font-mono text-xs font-semibold uppercase tracking-[0.12em] text-app-muted">
              Collateral class
            </p>
            <p id="asset-context-rarity" class="mt-2 truncate text-sm font-semibold text-app-fg">
              {@asset.rarity}
            </p>
          </div>
          <p id="asset-context-type" class="mt-1 truncate font-mono text-xs text-app-muted">
            {@asset.asset_type}
          </p>
        </div>
      </Card.surface>

      <Card.surface padding="px-4 py-3" variant={:subtle}>
        <div class="flex min-w-0 items-center justify-between gap-3 xl:block">
          <div class="min-w-0">
            <p class="font-mono text-xs font-semibold uppercase tracking-[0.12em] text-app-muted">
              Position size
            </p>
            <p
              id="asset-context-value"
              class="mt-2 font-mono text-sm font-semibold tabular-nums text-app-fg"
            >
              {Formatters.usd(@asset.current_value_usd)} collateral
            </p>
          </div>
          <p id="asset-context-loan" class="mt-1 font-mono text-xs text-app-muted">
            {Formatters.usd(@asset.loan_value_usd)} borrowed
          </p>
        </div>
      </Card.surface>

      <Card.surface padding="px-4 py-3" variant={:subtle}>
        <div class="flex min-w-0 items-center justify-between gap-3 xl:block">
          <div class="min-w-0">
            <p class="font-mono text-xs font-semibold uppercase tracking-[0.12em] text-app-muted">
              Signal quality
            </p>
            <div class="mt-2 flex flex-wrap gap-2">
              <Badge.render
                id="asset-context-oracle"
                label={@asset.oracle_status}
                tone={signal_tone(@asset.oracle_status)}
              />
              <Badge.render
                id="asset-context-liquidity"
                label={@asset.liquidity_status}
                tone={signal_tone(@asset.liquidity_status)}
              />
            </div>
          </div>
          <p id="asset-context-depth" class="mt-2 font-mono text-xs text-app-muted">
            {Formatters.usd(@asset.market_depth_usd)} market depth
          </p>
        </div>
      </Card.surface>
    </section>
    """
  end

  defp signal_tone("Fresh"), do: :success
  defp signal_tone("Deep"), do: :success
  defp signal_tone("Delayed"), do: :warning
  defp signal_tone("Thin"), do: :warning
  defp signal_tone("Stale"), do: :danger
  defp signal_tone("Illiquid"), do: :danger
  defp signal_tone(_signal), do: :neutral
end
