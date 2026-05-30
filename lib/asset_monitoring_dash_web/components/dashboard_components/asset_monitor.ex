defmodule AssetMonitoringDashWeb.DashboardComponents.AssetMonitor do
  @moduledoc """
  Full asset monitor section: filters, summary, scenario state, and asset table.
  """

  use Phoenix.Component

  alias AssetMonitoringDash.Assets
  alias AssetMonitoringDashWeb.DashboardComponents.AssetSummary
  alias AssetMonitoringDashWeb.DashboardComponents.AssetTable
  alias AssetMonitoringDashWeb.DashboardComponents.ScenarioBanner
  alias AssetMonitoringDashWeb.UI.Button
  alias AssetMonitoringDashWeb.UI.FilterBar
  alias AssetMonitoringDashWeb.UI.LoadStatus
  alias AssetMonitoringDashWeb.UI.Panel
  alias AssetMonitoringDashWeb.UI.SectionHeader

  attr :action_filter_options, :list, required: true
  attr :active_filter_chips, :list, required: true
  attr :asset_count, :integer, required: true
  attr :asset_filters, :map, required: true
  attr :asset_loaded_count, :integer, required: true
  attr :asset_next_cursor, :any, required: true
  attr :asset_sort, :map, required: true
  attr :asset_sort_options, :list, required: true
  attr :asset_summary, :map, required: true
  attr :chain_filter_options, :list, required: true
  attr :filter_form, :any, required: true
  attr :operator_state_filter_options, :list, required: true
  attr :risk_filter_options, :list, required: true
  attr :rows, :any, required: true
  attr :scenario_count, :integer, required: true

  def render(assigns) do
    ~H"""
    <Panel.render id="asset-monitor">
      <SectionHeader.render
        title="Asset monitor"
        description="Collateral assets grouped across chains, games, floor prices, and risk bands."
      >
        <:actions>
          <span
            id="asset-count"
            class="rounded-full bg-app-surface-2 px-3 py-1 text-xs font-medium text-app-muted ring-1 ring-app-border"
          >
            {@asset_count} monitored
          </span>
        </:actions>
      </SectionHeader.render>

      <FilterBar.render
        form={@filter_form}
        id="asset-filters"
        phx-change="filter_assets"
        class="mt-5"
      >
        <FilterBar.search
          field={@filter_form[:query]}
          placeholder="Search asset, chain, game, risk"
          autocomplete="off"
          class="h-12"
        />
        <div class="flex flex-wrap items-center gap-2">
          <FilterBar.multi_select
            field={@filter_form[:chains]}
            search_field={@filter_form[:chain_option_query]}
            label="Network"
            icon="hero-globe-alt"
            search_placeholder="Find network"
            options={visible_filter_options(@chain_filter_options, @asset_filters.chain_option_query)}
          />
          <FilterBar.multi_select
            field={@filter_form[:risks]}
            search_field={@filter_form[:risk_option_query]}
            label="Risk"
            icon="hero-shield-exclamation"
            search_placeholder="Find risk tier"
            options={visible_filter_options(@risk_filter_options, @asset_filters.risk_option_query)}
          />
          <FilterBar.multi_select
            field={@filter_form[:actions]}
            search_field={@filter_form[:action_option_query]}
            label="Action"
            icon="hero-bolt"
            search_placeholder="Find action"
            options={
              visible_filter_options(@action_filter_options, @asset_filters.action_option_query)
            }
          />
          <FilterBar.multi_select
            field={@filter_form[:operator_states]}
            search_field={@filter_form[:operator_state_option_query]}
            label="Operator"
            icon="hero-user-circle"
            search_placeholder="Find operator state"
            options={
              visible_filter_options(
                @operator_state_filter_options,
                @asset_filters.operator_state_option_query
              )
            }
          />
          <Button.render
            id="reset-asset-filters"
            phx-click="reset_asset_filters"
            class="h-11 rounded-app px-4"
          >
            Reset
          </Button.render>
        </div>
      </FilterBar.render>

      <div
        :if={@active_filter_chips != []}
        id="active-filter-chips"
        class="mt-3 flex flex-wrap items-center gap-2"
      >
        <FilterBar.active_chip :for={chip <- @active_filter_chips} chip={chip} />
      </div>

      <ScenarioBanner.render scenario_count={@scenario_count} />
      <AssetSummary.render summary={@asset_summary} />

      <LoadStatus.render
        count={@asset_count}
        loaded_count={@asset_loaded_count}
        status_id="asset-loaded-count"
        hint_id="asset-load-hint"
        show_hint={!!@asset_next_cursor}
      />

      <AssetTable.render
        rows={@rows}
        asset_next_cursor={@asset_next_cursor}
        asset_sort={@asset_sort}
        asset_sort_options={@asset_sort_options}
      />
    </Panel.render>
    """
  end

  defp visible_filter_options(options, query) do
    Assets.filter_options(options, query)
  end
end
