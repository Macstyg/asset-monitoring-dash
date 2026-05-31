defmodule AssetMonitoringDash.EventFeed do
  @moduledoc """
  Product rules for the dashboard activity feed.

  The feed is persisted by `EventStore`, while this module owns event
  enrichment and list presentation rules: source/severity metadata, relative
  labels, replacement by event id, and visible history bounds.
  """

  alias AssetMonitoringDash.Assets
  alias AssetMonitoringDash.DemoData
  alias AssetMonitoringDash.Money
  alias AssetMonitoringDash.ReviewAudit

  @visible_event_limit 6
  @event_tick_interval_seconds 4
  @demo_event_date ~D[2026-05-31]

  def visible_event_limit, do: @visible_event_limit

  def initial_events do
    Enum.map(DemoData.live_events(), &put_event_metadata(Map.put_new(&1, :kind, :system)))
  end

  def initial_event_keys do
    initial_events()
    |> Enum.map(& &1.id)
  end

  def timeline_events(events) do
    events
    |> Enum.map(&put_event_metadata/1)
    |> Enum.take(@visible_event_limit)
    |> refresh_live_event_labels()
  end

  def demo_event(next_event_index) do
    next_event_index
    |> DemoData.next_live_event()
    |> Map.put(:kind, :system)
    |> put_event_metadata()
  end

  def visible_events_for_asset(generated_events, asset_id) do
    generated_events
    |> Enum.map(&put_event_metadata/1)
    |> Enum.filter(&asset_event?(&1, asset_id))
    |> Enum.take(@visible_event_limit)
    |> refresh_live_event_labels()
  end

  def push_price_shock_event(visible_events, asset, drop_percent) do
    event_asset_key = event_asset_key(asset)

    event = %{
      id: "event-shock-#{event_asset_key}",
      asset_id: asset.id,
      time_label: "now",
      title: "Price shock applied",
      detail: "#{asset.name} repriced #{drop_percent}% lower; LTV is now #{format_ltv(asset)}.",
      chain: asset.chain,
      kind: :scenario,
      status: "risk",
      tone: :danger
    }

    push_event(visible_events, event)
  end

  def push_scenario_reset_event(visible_events, asset) do
    event_asset_key = event_asset_key(asset)

    event = %{
      id: "event-reset-#{event_asset_key}",
      asset_id: asset.id,
      time_label: "now",
      title: "Scenario reset",
      detail: "#{asset.name} restored to the baseline demo valuation.",
      chain: asset.chain,
      kind: :scenario,
      status: "synced",
      tone: :success
    }

    push_event(visible_events, event)
  end

  def push_review_event(visible_events, asset, review_state, audit_context \\ %{}) do
    review_audit = ReviewAudit.normalize(audit_context)

    event =
      asset
      |> review_event(review_state, review_audit)
      |> Map.put(:time_label, "now")

    push_event(visible_events, event)
  end

  def push_review_decision_event(visible_events, asset, review_decision) do
    review_audit = ReviewAudit.normalize(review_decision.audit)

    event =
      asset
      |> review_event(
        %{
          id: review_decision.state_id,
          label: review_decision.state_label,
          tone: review_decision.state_tone
        },
        review_audit
      )
      |> Map.put(:actor, review_decision.actor)
      |> Map.put(:occurred_at, review_decision.occurred_at)
      |> Map.put(:time_label, "now")

    push_event(visible_events, event)
  end

  defp push_event(visible_events, event) do
    event = put_event_metadata(event)

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

  defp put_missing_event_kind(%{kind: _kind} = event), do: event

  defp put_missing_event_kind(%{id: "event-shock-" <> _id} = event),
    do: Map.put(event, :kind, :scenario)

  defp put_missing_event_kind(%{id: "event-reset-" <> _id} = event),
    do: Map.put(event, :kind, :scenario)

  defp put_missing_event_kind(%{id: "event-review-" <> _id} = event),
    do: Map.put(event, :kind, :operator)

  defp put_missing_event_kind(event), do: Map.put(event, :kind, :system)

  defp put_event_metadata(event) do
    event
    |> put_missing_event_kind()
    |> put_source_metadata()
    |> put_severity_metadata()
    |> put_actor_metadata()
    |> put_occurred_at()
  end

  defp put_source_metadata(%{kind: kind} = event) when is_atom(kind) do
    event
    |> Map.put_new(:source_value, Atom.to_string(kind))
    |> Map.put_new(:source_label, source_label(kind))
    |> Map.put_new(:source_tone, source_tone(kind))
  end

  defp put_source_metadata(event), do: put_source_metadata(Map.put(event, :kind, :system))

  defp put_severity_metadata(%{tone: tone} = event) do
    event
    |> Map.put_new(:severity_label, severity_label(tone))
    |> Map.put_new(:severity_tone, severity_tone(tone))
  end

  defp put_actor_metadata(%{kind: kind} = event) when is_atom(kind) do
    Map.put_new(event, :actor, actor_label(kind))
  end

  defp put_occurred_at(%{occurred_at: _occurred_at} = event), do: event

  defp put_occurred_at(%{time_label: "now"} = event) do
    Map.put(event, :occurred_at, DateTime.utc_now(:microsecond))
  end

  defp put_occurred_at(%{time_label: time_label} = event) do
    case Time.from_iso8601(time_label) do
      {:ok, time} ->
        Map.put(event, :occurred_at, DateTime.new!(@demo_event_date, time, "Etc/UTC"))

      {:error, _reason} ->
        Map.put(event, :occurred_at, nil)
    end
  end

  defp put_occurred_at(event), do: Map.put(event, :occurred_at, nil)

  defp source_label(:operator), do: "Operator"
  defp source_label(:scenario), do: "Scenario"
  defp source_label(:system), do: "System"
  defp source_label(_kind), do: "System"

  defp source_tone(:operator), do: :success
  defp source_tone(:scenario), do: :warning
  defp source_tone(:system), do: :info
  defp source_tone(_kind), do: :info

  defp severity_label(:danger), do: "Critical"
  defp severity_label(:warning), do: "Watch"
  defp severity_label(:success), do: "Normal"
  defp severity_label(:neutral), do: "Info"
  defp severity_label(_tone), do: "Info"

  defp severity_tone(:danger), do: :danger
  defp severity_tone(:warning), do: :warning
  defp severity_tone(:success), do: :success
  defp severity_tone(:neutral), do: :neutral
  defp severity_tone(_tone), do: :neutral

  defp actor_label(:operator), do: "Operator"
  defp actor_label(:scenario), do: "Scenario engine"
  defp actor_label(:system), do: "Monitoring system"
  defp actor_label(_kind), do: "Monitoring system"

  defp asset_event?(%{asset_id: event_asset_id}, asset_id) do
    Assets.same_asset_id?(event_asset_id, asset_id)
  end

  defp asset_event?(_event, _asset_id), do: false

  defp review_event(asset, %{id: :reviewed}, audit_context) do
    event_asset_key = event_asset_key(asset)

    %{
      id: "event-review-reviewed-#{event_asset_key}",
      asset_id: asset.id,
      title: "Position reviewed",
      detail:
        review_event_detail(
          "#{asset.name} marked reviewed by an operator.",
          audit_context
        ),
      chain: asset.chain,
      kind: :operator,
      review_audit: audit_context,
      review_reason: audit_context.reason,
      operator_note: audit_context.note,
      status: "reviewed",
      tone: :success
    }
  end

  defp review_event(asset, %{id: :escalated}, audit_context) do
    event_asset_key = event_asset_key(asset)

    %{
      id: "event-review-escalated-#{event_asset_key}",
      asset_id: asset.id,
      title: "Review escalated",
      detail: review_event_detail("#{asset.name} escalated for follow-up.", audit_context),
      chain: asset.chain,
      kind: :operator,
      review_audit: audit_context,
      review_reason: audit_context.reason,
      operator_note: audit_context.note,
      status: "review",
      tone: :warning
    }
  end

  defp review_event(asset, %{id: :unreviewed}, audit_context) do
    event_asset_key = event_asset_key(asset)

    %{
      id: "event-review-unreviewed-#{event_asset_key}",
      asset_id: asset.id,
      title: "Review state reset",
      detail:
        review_event_detail(
          "#{asset.name} returned to unreviewed after scenario inputs changed.",
          audit_context
        ),
      chain: asset.chain,
      kind: :operator,
      review_audit: audit_context,
      review_reason: audit_context.reason,
      operator_note: audit_context.note,
      status: "review",
      tone: :neutral
    }
  end

  defp review_event_detail(detail, %{reason: "", note: ""}), do: detail

  defp review_event_detail(detail, %{reason: reason, note: ""}) do
    "#{detail} Reason: #{reason}."
  end

  defp review_event_detail(detail, %{reason: "", note: note}) do
    "#{detail} Note: #{note}"
  end

  defp review_event_detail(detail, %{reason: reason, note: note}) do
    "#{detail} Reason: #{reason}. Note: #{note}"
  end

  defp format_ltv(asset) do
    asset.ltv_percent
    |> Money.decimal()
    |> Decimal.round(1)
    |> Decimal.to_string(:normal)
    |> Kernel.<>("%")
  end

  defp event_asset_key(%{dom_id: dom_id}) when is_binary(dom_id), do: dom_id
  defp event_asset_key(%{id: id}), do: id
end
