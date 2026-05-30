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

  def visible_events(generated_events) do
    generated_events
    |> Kernel.++(initial_events())
    |> Enum.take(@visible_event_limit)
    |> refresh_live_event_labels()
  end

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

  def push_scenario_reset_event(visible_events, asset) do
    event = %{
      id: "event-reset-#{asset.id}",
      time_label: "now",
      title: "Scenario reset",
      detail: "#{asset.name} restored to the baseline demo valuation.",
      chain: asset.chain,
      status: "synced",
      tone: :success
    }

    push_event(visible_events, event)
  end

  def push_review_event(visible_events, asset, review_state) do
    event =
      asset
      |> review_event(review_state)
      |> Map.put(:time_label, "now")

    push_event(visible_events, event)
  end

  defp push_event(visible_events, event) do
    visible_events =
      [event | Enum.reject(visible_events, &(&1.id == event.id))]
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

  defp refresh_live_event_label(%{id: "event-reset-" <> _id} = event, 0) do
    %{event | time_label: "now"}
  end

  defp refresh_live_event_label(%{id: "event-reset-" <> _id} = event, index) do
    %{event | time_label: "#{index * @event_tick_interval_seconds}s ago"}
  end

  defp refresh_live_event_label(%{id: "event-review-" <> _id} = event, 0) do
    %{event | time_label: "now"}
  end

  defp refresh_live_event_label(%{id: "event-review-" <> _id} = event, index) do
    %{event | time_label: "#{index * @event_tick_interval_seconds}s ago"}
  end

  defp refresh_live_event_label(event, _index), do: event

  defp review_event(asset, %{id: :reviewed}) do
    %{
      id: "event-review-reviewed-#{asset.id}",
      title: "Position reviewed",
      detail: "#{asset.name} marked reviewed by an operator.",
      chain: asset.chain,
      status: "reviewed",
      tone: :success
    }
  end

  defp review_event(asset, %{id: :escalated}) do
    %{
      id: "event-review-escalated-#{asset.id}",
      title: "Review escalated",
      detail: "#{asset.name} escalated for follow-up.",
      chain: asset.chain,
      status: "review",
      tone: :warning
    }
  end
end
