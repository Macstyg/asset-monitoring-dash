defmodule AssetMonitoringDash.AssetScenario do
  @moduledoc """
  Persisted scenario flag for demo controls applied to a monitored asset.
  """

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "asset_scenarios" do
    field :asset_id, :binary_id
    field :scenario_id, :string

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(asset_scenario, attrs) do
    asset_scenario
    |> cast(attrs, [:asset_id, :scenario_id])
    |> validate_required([:asset_id, :scenario_id])
  end
end
