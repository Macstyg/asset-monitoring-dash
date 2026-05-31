defmodule AssetMonitoringDashWeb.DashboardComponents.AssetActivity do
  @moduledoc """
  Asset-scoped activity timeline with source filtering.
  """

  use Phoenix.Component

  alias AssetMonitoringDashWeb.DashboardComponents.EventItem
  alias AssetMonitoringDashWeb.UI.Card
  alias AssetMonitoringDashWeb.UI.FilterBar

  attr :active_filter_chips, :list, required: true
  attr :event_count, :integer, required: true
  attr :event_filter_form, :any, required: true
  attr :event_filters, :map, required: true
  attr :rows, :any, required: true
  attr :source_filter_options, :list, required: true

  def render(assigns) do
    ~H"""
    <Card.surface
      id="asset-activity"
      class="min-h-72"
    >
      <div class="flex items-start justify-between gap-4">
        <div>
          <h2 class="text-base font-semibold text-app-fg">Asset activity</h2>
          <p class="mt-1 text-sm text-app-muted">
            Recorded scenario and operator events for this asset.
          </p>
        </div>
        <span
          id="asset-event-count"
          class="rounded-full bg-app-surface-2 px-3 py-1 text-xs font-medium text-app-muted ring-1 ring-app-border"
        >
          {@event_count} events
        </span>
      </div>

      <FilterBar.render
        form={@event_filter_form}
        id="asset-activity-filters"
        phx-change="filter_asset_events"
        class="mt-4"
      >
        <div class="flex flex-wrap items-center gap-2">
          <FilterBar.multi_select
            field={@event_filter_form[:sources]}
            search_field={@event_filter_form[:source_option_query]}
            label="Source"
            icon="hero-funnel"
            search_placeholder="Find source"
            options={
              visible_source_options(@source_filter_options, @event_filters.source_option_query)
            }
          />
        </div>
      </FilterBar.render>

      <div
        :if={@active_filter_chips != []}
        id="active-asset-event-filter-chips"
        class="mt-3 flex flex-wrap items-center gap-2"
      >
        <FilterBar.active_chip :for={chip <- @active_filter_chips} chip={chip} />
      </div>

      <div
        id="asset-event-list"
        phx-update="stream"
        class="mt-5"
      >
        <div
          id="asset-event-list-empty"
          class="hidden only:block rounded-app border border-dashed border-app-border bg-app-surface-2 px-4 py-8 text-center text-sm text-app-muted"
        >
          {empty_title(@event_filters)}
        </div>

        <EventItem.render
          :for={{event_id, event} <- @rows}
          id={event_id}
          actor={event.actor}
          time_label={event.time_label}
          title={event.title}
          detail={event.detail}
          chain={event.chain}
          source_label={event.source_label}
          source_tone={event.source_tone}
          severity_label={event.severity_label}
          severity_tone={event.severity_tone}
          status={event.status}
          tone={event.tone}
        />
      </div>
    </Card.surface>
    """
  end

  defp visible_source_options(options, ""), do: options

  defp visible_source_options(options, query) do
    Enum.filter(options, fn option ->
      option
      |> Map.fetch!(:label)
      |> String.downcase()
      |> String.contains?(query)
    end)
  end

  defp empty_title(%{sources: []}), do: "No recorded activity for this asset yet."
  defp empty_title(_filters), do: "No activity matches these filters."
end
