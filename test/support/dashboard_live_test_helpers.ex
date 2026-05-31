defmodule AssetMonitoringDashWeb.DashboardLiveTestHelpers do
  @moduledoc false

  import Phoenix.LiveViewTest, only: [render: 1]

  alias AssetMonitoringDash.Assets

  def asset_row_ids(view) do
    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query("#asset-list-rows > div")
    |> LazyHTML.attribute("id")
    |> Enum.filter(&String.starts_with?(&1, "asset-row-"))
  end

  def patch_query_params(path) do
    path
    |> URI.parse()
    |> Map.fetch!(:query)
    |> case do
      nil -> %{}
      query -> URI.decode_query(query)
    end
  end

  def expected_first_asset_row_id(sort, opts \\ []) do
    sort
    |> expected_asset_row_ids(opts)
    |> List.first()
  end

  def expected_asset_row_ids(sort, opts) do
    filters = Keyword.get(opts, :filters, Assets.default_filters())
    review_states = Keyword.get(opts, :review_states, %{})
    shocked_asset_ids = Keyword.get(opts, :shocked_asset_ids, MapSet.new())
    limit = Keyword.get(opts, :limit, 50)

    %{
      filters: filters,
      sort: sort,
      cursor: nil,
      limit: limit,
      review_states: review_states,
      shocked_asset_ids: shocked_asset_ids
    }
    |> Assets.list_persisted_assets_page()
    |> Map.fetch!(:entries)
    |> Enum.map(&"asset-row-#{&1.dom_id}")
  end

  def asset_fixture(asset_id) do
    Assets.get_asset(asset_id)
  end
end
