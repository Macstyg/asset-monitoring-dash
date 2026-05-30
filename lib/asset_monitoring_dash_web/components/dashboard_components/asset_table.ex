defmodule AssetMonitoringDashWeb.DashboardComponents.AssetTable do
  @moduledoc """
  Product table for monitored collateral assets.
  """

  use Phoenix.Component

  import AssetMonitoringDashWeb.CoreComponents, only: [icon: 1]

  alias AssetMonitoringDashWeb.DashboardComponents.ChainIdentity
  alias AssetMonitoringDashWeb.DashboardComponents.RiskBadge
  alias AssetMonitoringDashWeb.Formatters
  alias AssetMonitoringDashWeb.UI.Badge
  alias AssetMonitoringDashWeb.UI.EntityIdentity
  alias AssetMonitoringDashWeb.UI.Table

  attr :asset_next_cursor, :any, required: true
  attr :asset_sort, :map, required: true
  attr :asset_sort_options, :list, required: true
  attr :loaded_count, :integer, required: true
  attr :rows, :any, required: true
  attr :total_count, :integer, required: true

  def render(assigns) do
    ~H"""
    <div>
      <div id="asset-mobile-sort" class="mt-5 flex flex-wrap items-center gap-2 lg:hidden">
        <button
          :for={sort <- @asset_sort_options}
          id={"asset-mobile-sort-#{sort.field}"}
          type="button"
          phx-click="sort_assets"
          phx-value-field={sort.field}
          class={[
            "inline-flex h-9 items-center gap-1.5 rounded-full border px-3 text-xs font-semibold transition",
            Atom.to_string(@asset_sort.field) == sort.field &&
              "border-app-accent/40 bg-app-accent/10 text-app-accent",
            Atom.to_string(@asset_sort.field) != sort.field &&
              "border-app-border bg-app-surface-2 text-app-muted hover:border-app-accent/40 hover:text-app-fg"
          ]}
        >
          {sort.label}
          <.icon
            :if={Atom.to_string(@asset_sort.field) == sort.field}
            name="hero-chevron-down"
            class={[
              "size-3.5 transition",
              @asset_sort.direction == :asc && "rotate-180"
            ]}
          />
        </button>
      </div>

      <Table.render
        id="asset-list"
        label="Monitored assets"
        class="mt-5"
        grid_class="grid-cols-[minmax(170px,1.1fr)_minmax(150px,0.8fr)_86px_86px_66px_80px_minmax(120px,0.75fr)_minmax(150px,1fr)]"
        row_class="lg:min-w-[1120px] lg:grid-cols-[minmax(170px,1.1fr)_minmax(150px,0.8fr)_86px_86px_66px_80px_minmax(120px,0.75fr)_minmax(150px,1fr)] lg:items-center"
        row_click="select_asset"
        load_more_target_id="asset-table-loading"
        rows_class="max-h-[min(62vh,760px)] overflow-y-auto overscroll-contain [scrollbar-gutter:stable]"
        rows={@rows}
        sort_direction={@asset_sort.direction}
        sort_event="sort_assets"
        sort_field={@asset_sort.field}
        viewport_bottom={@asset_next_cursor && "load_more_assets"}
      >
        <:col sort_key="asset">Asset</:col>
        <:col sort_key="chain">Chain / game</:col>
        <:col align={:right} sort_key="floor">Floor</:col>
        <:col align={:right} sort_key="value">Value</:col>
        <:col align={:right} sort_key="ltv">LTV</:col>
        <:col align={:right} sort_key="risk">Risk</:col>
        <:col align={:right} sort_key="operator">Operator</:col>
        <:col align={:right} sort_key="action">Action</:col>

        <:empty>
          <div class="mx-auto max-w-sm">
            <p class="font-semibold text-app-fg">No assets match this filter.</p>
            <p class="mt-1 text-sm leading-6 text-app-muted">
              Try a broader search, switch chains, or reset the filters.
            </p>
          </div>
        </:empty>

        <:row :let={asset}>
          <EntityIdentity.render
            name={asset.name}
            caption={"#{asset.rarity} / #{asset.asset_type}"}
            asset_icon={asset.icon}
          />

          <ChainIdentity.render chain={asset.chain} ecosystem={asset.ecosystem} />

          <Table.cell label="Floor" align={:right}>
            <span class="font-mono text-sm font-semibold tabular-nums text-app-fg">
              {Formatters.usd(asset.floor_price_usd)}
            </span>
          </Table.cell>

          <Table.cell label="Value" align={:right}>
            <span class="font-mono text-sm font-semibold tabular-nums text-app-fg">
              {Formatters.usd(asset.current_value_usd)}
            </span>
          </Table.cell>

          <Table.cell label="LTV" align={:right}>
            <span class="font-mono text-sm font-semibold tabular-nums text-app-fg">
              {Formatters.ltv(asset.ltv_percent)}
            </span>
          </Table.cell>

          <Table.cell label="Risk" align={:right} content_class="lg:flex lg:justify-end">
            <RiskBadge.render label={asset.risk_band} />
          </Table.cell>

          <Table.cell label="Operator" align={:right} content_class="lg:flex lg:justify-end">
            <Badge.render label={asset.review_state.label} tone={asset.review_state.tone} />
          </Table.cell>

          <Table.cell label="Action" align={:right} content_class="lg:flex lg:justify-end">
            <div class="flex min-w-0 flex-col items-end gap-1">
              <Badge.render
                label={asset.risk_recommendation.label}
                tone={asset.risk_recommendation.tone}
              />
              <Badge.render
                :if={asset.scenario}
                id={"asset-scenario-#{asset.id}"}
                label={asset.scenario.label}
                tone={asset.scenario.tone}
              />
              <span class="max-w-36 truncate font-mono text-xs text-app-muted">
                {asset.recommendation_reason.label}
              </span>
            </div>
          </Table.cell>
        </:row>
      </Table.render>

      <div
        id="asset-table-pagination-status"
        class="mt-2 flex flex-wrap items-center justify-between gap-2 text-xs text-app-muted"
      >
        <span id="asset-table-range" class="font-mono">
          {range_label(@loaded_count, @total_count)}
        </span>
        <span
          id="asset-table-loading"
          class="hidden rounded-full bg-app-accent/10 px-2.5 py-1 font-mono text-app-accent ring-1 ring-app-accent/20"
        >
          Loading more...
        </span>
        <span
          :if={!@asset_next_cursor && @total_count > 0}
          id="asset-table-end"
          class="rounded-full bg-app-surface-2 px-2.5 py-1 font-mono ring-1 ring-app-border"
        >
          All matching assets loaded
        </span>
      </div>
    </div>
    """
  end

  defp range_label(0, count), do: "Showing 0 of #{count}"

  defp range_label(loaded_count, count) do
    "Showing 1-#{min(loaded_count, count)} of #{count}"
  end
end
