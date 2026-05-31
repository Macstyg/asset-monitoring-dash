defmodule AssetMonitoringDash.Assets.GameEcosystem do
  @moduledoc """
  Game/economy dimension for monitored collateral assets.
  """

  use Ecto.Schema

  import Ecto.Changeset

  alias AssetMonitoringDash.Assets.MonitoredAsset

  schema "game_ecosystems" do
    field :genre, :string
    field :name, :string
    field :slug, :string

    has_many :monitored_assets, MonitoredAsset

    timestamps(type: :utc_datetime)
  end

  def changeset(game_ecosystem, attrs) do
    game_ecosystem
    |> cast(attrs, [:name, :slug, :genre])
    |> validate_required([:name, :slug, :genre])
    |> unique_constraint(:name)
    |> unique_constraint(:slug)
  end
end
