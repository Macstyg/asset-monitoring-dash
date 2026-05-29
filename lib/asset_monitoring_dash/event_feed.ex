defmodule AssetMonitoringDash.EventFeed do
  @moduledoc """
  Product rules for the dashboard activity feed.

  The current feed is driven by deterministic demo events, but the module owns
  the same rules a real feed will need: inserting newest items first, bounding
  visible history, and refreshing relative labels for generated live events.
  """

  alias AssetMonitoringDash.DemoData

  @visible_event_limit 6
  @event_tick_interval_seconds 4

  def initial_events, do: DemoData.live_events()

  def push_demo_event(visible_events, next_event_index) do
    event = DemoData.next_live_event(next_event_index)

    push_event(visible_events, event)
    |> Map.put(:next_event_index, next_event_index + 1)
  end

  def push_price_shock_event(visible_events, asset, drop_percent) do
    event = %{
      id: "event-shock-#{asset.id}",
      time_label: "now",
      title: "Price shock applied",
      detail: "#{asset.name} repriced #{drop_percent}% lower; LTV is now #{asset.ltv_percent}%.",
      chain: asset.chain,
      status: "risk",
      tone: :danger
    }

    push_event(visible_events, event)
  end

  defp push_event(visible_events, event) do
    visible_events =
      [event | visible_events]
      |> Enum.take(@visible_event_limit)
      |> refresh_live_event_labels()

    %{
      visible_events: visible_events
    }
  end

  defp refresh_live_event_labels(events) do
    events
    |> Enum.with_index()
    |> Enum.map(fn {event, index} -> refresh_live_event_label(event, index) end)
  end

  defp refresh_live_event_label(%{id: "event-live-" <> _id} = event, 0) do
    %{event | time_label: "now"}
  end

  defp refresh_live_event_label(%{id: "event-live-" <> _id} = event, index) do
    %{event | time_label: "#{index * @event_tick_interval_seconds}s ago"}
  end

  defp refresh_live_event_label(%{id: "event-shock-" <> _id} = event, 0) do
    %{event | time_label: "now"}
  end

  defp refresh_live_event_label(%{id: "event-shock-" <> _id} = event, index) do
    %{event | time_label: "#{index * @event_tick_interval_seconds}s ago"}
  end

  defp refresh_live_event_label(event, _index), do: event
end
