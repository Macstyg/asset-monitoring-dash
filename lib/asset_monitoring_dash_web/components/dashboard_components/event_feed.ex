defmodule AssetMonitoringDashWeb.DashboardComponents.EventFeed do
  @moduledoc """
  Product section for live operational event history.
  """

  use Phoenix.Component

  alias AssetMonitoringDashWeb.DashboardComponents.EventItem
  alias AssetMonitoringDashWeb.UI.Button
  alias AssetMonitoringDashWeb.UI.FilterBar
  alias AssetMonitoringDashWeb.UI.Panel
  alias AssetMonitoringDashWeb.UI.SectionHeader

  attr :active_event_filter_chips, :list, required: true
  attr :event_count, :integer, required: true
  attr :event_filter_form, :any, required: true
  attr :event_filters, :map, required: true
  attr :event_source_filter_options, :list, required: true
  attr :feed_paused, :boolean, required: true
  attr :rows, :any, required: true

  def render(assigns) do
    ~H"""
    <Panel.render id="event-feed" class="min-h-72">
      <SectionHeader.render
        title="Live event feed"
        description="Deposits, transfers, price moves, repayments, and liquidation warnings."
      >
        <:actions>
          <span
            id="event-count"
            class="rounded-full bg-app-surface-2 px-3 py-1 text-xs font-medium text-app-muted ring-1 ring-app-border"
          >
            {@event_count} events
          </span>
          <span
            id="event-feed-state"
            class={[
              "rounded-full px-3 py-1 text-xs font-medium ring-1 ring-inset",
              if(@feed_paused,
                do: "bg-app-warn/10 text-app-warn ring-app-warn/25",
                else: "bg-app-accent/10 text-app-accent ring-app-accent/20"
              )
            ]}
          >
            {if(@feed_paused, do: "paused", else: "streaming")}
          </span>
        </:actions>
      </SectionHeader.render>

      <div class="mt-4 flex flex-wrap gap-2">
        <Button.render id="push-demo-event" phx-click="push_demo_event">
          Push event
        </Button.render>
        <Button.render id="toggle-event-feed" phx-click="toggle_event_feed">
          {if(@feed_paused, do: "Resume feed", else: "Pause feed")}
        </Button.render>
      </div>

      <FilterBar.render
        form={@event_filter_form}
        id="event-filters"
        phx-change="filter_events"
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
              visible_source_options(
                @event_source_filter_options,
                @event_filters.source_option_query
              )
            }
          />
        </div>
      </FilterBar.render>

      <div
        :if={@active_event_filter_chips != []}
        id="active-event-filter-chips"
        class="mt-3 flex flex-wrap items-center gap-2"
      >
        <FilterBar.active_chip :for={chip <- @active_event_filter_chips} chip={chip} />
      </div>

      <div id="event-list" phx-update="stream" class="mt-5">
        <div
          id="event-list-empty"
          class="hidden rounded-app border border-dashed border-app-border bg-app-surface-2 px-4 py-8 text-center only:block"
        >
          <p class="text-sm font-semibold text-app-fg">No events for this filter.</p>
          <p class="mt-1 text-sm text-app-muted">
            Choose another event source or wait for the feed to produce a matching event.
          </p>
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
    </Panel.render>
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
end
