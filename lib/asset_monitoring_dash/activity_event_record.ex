defmodule AssetMonitoringDash.ActivityEventRecord do
  @moduledoc """
  Persisted generated activity feed event.

  Seeded narrative events and generated operator/scenario events share this
  table so the dashboard feed can be queried from one persistence boundary.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @kinds ~w(system scenario operator)
  @tones ~w(neutral success warning danger)

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "activity_events" do
    field :actor, :string
    field :asset_id, :binary_id
    field :chain, :string
    field :detail, :string
    field :event_key, :string
    field :kind, :string
    field :operator_note, :string, default: ""
    field :occurred_at, :utc_datetime_usec
    field :review_reason, :string, default: ""
    field :status, :string
    field :title, :string
    field :tone, :string

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(activity_event_record, attrs) do
    activity_event_record
    |> cast(attrs, [
      :actor,
      :asset_id,
      :chain,
      :detail,
      :event_key,
      :kind,
      :operator_note,
      :occurred_at,
      :review_reason,
      :status,
      :title,
      :tone
    ])
    |> validate_required([
      :actor,
      :chain,
      :detail,
      :event_key,
      :kind,
      :occurred_at,
      :status,
      :title,
      :tone
    ])
    |> validate_inclusion(:kind, @kinds)
    |> validate_inclusion(:tone, @tones)
  end
end
