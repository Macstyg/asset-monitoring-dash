defmodule AssetMonitoringDash.EventStore do
  @moduledoc """
  Persistent store for dashboard activity events.

  Seeded narrative events, scenario controls, live demo ticks, and operator
  workflow events all pass through this boundary so the feed is database-backed.
  """

  import Ecto.Query

  alias AssetMonitoringDash.ActivityEventRecord
  alias AssetMonitoringDash.Assets
  alias AssetMonitoringDash.EventFeed
  alias AssetMonitoringDash.Repo
  alias AssetMonitoringDash.ReviewAudit

  def visible_events do
    persisted_events()
    |> EventFeed.timeline_events()
  end

  def visible_events_for_asset(asset_id) do
    asset_id = Assets.resolve_persisted_asset_id(asset_id)

    persisted_events()
    |> EventFeed.visible_events_for_asset(asset_id)
  end

  def seed_initial_events! do
    EventFeed.initial_events()
    |> Enum.each(&persist_event!/1)

    :ok
  end

  def push_demo_event(next_event_index) do
    next_event_index
    |> EventFeed.demo_event()
    |> persist_event!()

    %{
      event_history: visible_events(),
      next_event_index: next_event_index + 1
    }
  end

  def push_price_shock_event(asset, drop_percent) do
    event =
      []
      |> EventFeed.push_price_shock_event(asset, drop_percent)
      |> Map.fetch!(:visible_events)
      |> List.first()

    persist_event!(event)

    visible_events()
  end

  def push_scenario_reset_event(asset) do
    event =
      []
      |> EventFeed.push_scenario_reset_event(asset)
      |> Map.fetch!(:visible_events)
      |> List.first()

    persist_event!(event)

    visible_events()
  end

  def push_review_event(asset, review_state, audit_context \\ %{}) do
    event =
      []
      |> EventFeed.push_review_event(asset, review_state, audit_context)
      |> Map.fetch!(:visible_events)
      |> List.first()

    persist_event!(event)

    visible_events()
  end

  def push_review_decision_event(asset, review_decision) do
    event =
      []
      |> EventFeed.push_review_decision_event(asset, review_decision)
      |> Map.fetch!(:visible_events)
      |> List.first()

    persist_event!(event)

    visible_events()
  end

  def reset_all do
    Repo.delete_all(ActivityEventRecord)

    :ok
  end

  def reset_mutable_events do
    seeded_event_keys = EventFeed.initial_event_keys()

    ActivityEventRecord
    |> where([event], event.event_key not in ^seeded_event_keys)
    |> Repo.delete_all()

    :ok
  end

  defp persisted_events do
    seeded_event_keys = EventFeed.initial_event_keys()

    ActivityEventRecord
    |> order_by([event],
      desc:
        fragment("CASE WHEN ? = ANY(?) THEN 0 ELSE 1 END", event.event_key, ^seeded_event_keys),
      desc: event.occurred_at,
      desc: event.id
    )
    |> Repo.all()
    |> Enum.map(&record_to_event/1)
  end

  defp persist_event!(event) do
    %ActivityEventRecord{}
    |> ActivityEventRecord.changeset(event_attrs(event))
    |> Repo.insert!(
      on_conflict:
        {:replace_all_except,
         [
           :id,
           :inserted_at
         ]},
      conflict_target: :event_key
    )
  end

  defp event_attrs(event) do
    review_audit = ReviewAudit.normalize(Map.get(event, :review_audit, %{}))

    %{
      actor: event.actor,
      asset_id: event_asset_id(event),
      chain: event.chain,
      detail: event.detail,
      event_key: event.id,
      kind: event.kind |> Atom.to_string(),
      operator_note: review_audit.note,
      occurred_at: DateTime.truncate(event.occurred_at || DateTime.utc_now(), :microsecond),
      review_reason: review_audit.reason,
      status: event.status,
      title: event.title,
      tone: event.tone |> Atom.to_string()
    }
  end

  defp event_asset_id(%{asset_id: nil}), do: nil
  defp event_asset_id(%{asset_id: asset_id}), do: Assets.resolve_persisted_asset_id(asset_id)
  defp event_asset_id(_event), do: nil

  defp record_to_event(record) do
    %{
      id: record.event_key,
      actor: record.actor,
      asset_id: record.asset_id,
      chain: record.chain,
      detail: record.detail,
      kind: kind_atom(record.kind),
      occurred_at: record.occurred_at,
      operator_note: record.operator_note,
      review_audit: ReviewAudit.new(%{note: record.operator_note, reason: record.review_reason}),
      review_reason: record.review_reason,
      status: record.status,
      time_label: "now",
      title: record.title,
      tone: tone_atom(record.tone)
    }
  end

  defp kind_atom("operator"), do: :operator
  defp kind_atom("scenario"), do: :scenario
  defp kind_atom(_kind), do: :system

  defp tone_atom("danger"), do: :danger
  defp tone_atom("success"), do: :success
  defp tone_atom("warning"), do: :warning
  defp tone_atom(_tone), do: :neutral
end
