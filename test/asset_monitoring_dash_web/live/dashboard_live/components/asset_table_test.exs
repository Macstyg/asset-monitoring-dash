defmodule AssetMonitoringDashWeb.DashboardLive.Components.AssetTableTest do
  use AssetMonitoringDashWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias AssetMonitoringDashWeb.DashboardLive.Components.AssetTable

  test "renders asset rows with sort controls and pagination status" do
    document =
      render_component(&AssetTable.render/1,
        asset_next_cursor: "asset-002",
        asset_sort: %{field: :risk, direction: :desc},
        asset_sort_options: [
          %{field: "risk", label: "Risk"},
          %{field: "value", label: "Value"}
        ],
        loaded_count: 1,
        rows: [{"asset-row-asset-001", asset()}],
        total_count: 12
      )
      |> LazyHTML.from_fragment()

    assert document |> LazyHTML.query("#asset-list") |> Enum.any?()

    assert document
           |> LazyHTML.query("#asset-list-rows[phx-hook=\"ScrollableLoadMore\"]")
           |> Enum.any?()

    assert document
           |> LazyHTML.query("#asset-list-sort-risk[phx-click=\"sort_assets\"]")
           |> Enum.any?()

    assert document
           |> LazyHTML.query("#asset-mobile-sort-risk[phx-click=\"sort_assets\"]")
           |> Enum.any?()

    assert document
           |> LazyHTML.query("#asset-row-asset-001[phx-click=\"select_asset\"]")
           |> Enum.any?()

    assert document |> LazyHTML.query("#asset-row-asset-001") |> LazyHTML.text() =~
             "Aegis Dragon Helm"

    assert document |> LazyHTML.query("#asset-row-asset-001") |> LazyHTML.text() =~ "$4,860"

    assert document |> LazyHTML.query("#asset-table-range") |> LazyHTML.text() =~
             "Showing 1-1 of 12"

    assert document |> LazyHTML.query("#asset-table-loading") |> Enum.any?()
  end

  test "renders empty state when there are no rows" do
    document =
      render_component(&AssetTable.render/1,
        asset_next_cursor: nil,
        asset_sort: %{field: :ltv, direction: :desc},
        asset_sort_options: [],
        loaded_count: 0,
        rows: [],
        total_count: 0
      )
      |> LazyHTML.from_fragment()

    assert document |> LazyHTML.query("#asset-list-empty") |> LazyHTML.text() =~
             "No assets match this filter."

    assert document |> LazyHTML.query("#asset-table-range") |> LazyHTML.text() =~ "Showing 0 of 0"
  end

  defp asset do
    %{
      id: "asset-001",
      name: "Aegis Dragon Helm",
      icon: "dragon-helm.svg",
      rarity: "Legendary",
      asset_type: "NFT",
      chain: "Polygon",
      ecosystem: "Skyforge Arena",
      floor_price_usd: 4_200,
      current_value_usd: 4_860,
      ltv_percent: 59.7,
      risk_band: "Elevated",
      review_state: %{label: "Unreviewed", tone: :neutral},
      risk_recommendation: %{label: "Manual review", tone: :warning},
      recommendation_reason: %{label: "Elevated risk"},
      scenario: %{label: "Scenario", tone: :warning}
    }
  end
end
