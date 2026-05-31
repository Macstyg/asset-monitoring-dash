defmodule AssetMonitoringDash.Assets.Chain do
  @moduledoc """
  Blockchain network dimension for monitored collateral assets.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias AssetMonitoringDash.Assets.MonitoredAsset

  schema "chains" do
    field :name, :string
    field :native_token, :string
    field :slug, :string

    has_many :monitored_assets, MonitoredAsset

    timestamps(type: :utc_datetime)
  end

  def changeset(chain, attrs) do
    chain
    |> cast(attrs, [:name, :slug, :native_token])
    |> validate_required([:name, :slug, :native_token])
    |> unique_constraint(:name)
    |> unique_constraint(:slug)
  end
end
