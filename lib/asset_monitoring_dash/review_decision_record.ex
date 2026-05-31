defmodule AssetMonitoringDash.ReviewDecisionRecord do
  @moduledoc """
  Persisted audit record for operator review workflow decisions.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @state_ids ~w(unreviewed reviewed escalated)

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "review_decisions" do
    field :actor, :string
    field :asset_id, :binary_id
    field :note, :string
    field :occurred_at, :utc_datetime_usec
    field :reason, :string
    field :state_id, :string

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(review_decision_record, attrs) do
    review_decision_record
    |> cast(attrs, [
      :actor,
      :asset_id,
      :note,
      :occurred_at,
      :reason,
      :state_id
    ])
    |> validate_required([
      :actor,
      :asset_id,
      :occurred_at,
      :state_id
    ])
    |> validate_inclusion(:state_id, @state_ids)
  end
end
