defmodule AssetMonitoringDashWeb.DashboardLive.Components.AssetMonitorTest do
  use AssetMonitoringDashWeb.ComponentCase, async: true

  alias AssetMonitoringDashWeb.DashboardLive.Components.AssetMonitor

  test "renders the dashboard asset workspace" do
    filters = filters()

    document =
      render_component(&AssetMonitor.render/1,
        action_filter_options: [%{value: "manual_review", label: "Manual review"}],
        active_filter_chips: [query_chip()],
        asset_count: 12,
        asset_filters: filters,
        asset_loaded_count: 1,
        asset_next_cursor: "asset-002",
        asset_sort: %{field: :risk, direction: :desc},
        asset_sort_options: [%{field: "risk", label: "Risk"}],
        asset_summary: %{
          visible_count: 12,
          total_value_usd: 42_500,
          at_risk_count: 3,
          highest_ltv_percent: 81.2
        },
        asset_view_shared?: true,
        chain_filter_options: [%{value: "Polygon", label: "Polygon", icon: :chain}],
        filter_form: filter_form(filters),
        operator_state_filter_options: [%{value: "unreviewed", label: "Unreviewed"}],
        risk_filter_options: [%{value: "Elevated", label: "Elevated"}],
        rows: [{"asset-row-asset-001", asset()}],
        scenario_count: 1
      )
      |> LazyHTML.from_fragment()

    assert document |> LazyHTML.query("#asset-monitor") |> Enum.any?()
    assert document |> LazyHTML.query("#asset-view-state") |> LazyHTML.text() =~ "Filtered view"
    assert document |> LazyHTML.query("#copy-asset-view-link") |> Enum.any?()
    assert document |> LazyHTML.query("#asset-count") |> LazyHTML.text() =~ "12 monitored"
    assert document |> LazyHTML.query("#asset-filters") |> Enum.any?()
    assert document |> LazyHTML.query("#active-filter-query-anc") |> Enum.any?()
    assert document |> LazyHTML.query("#active-scenario-banner") |> Enum.any?()
    assert document |> LazyHTML.query("#asset-summary") |> Enum.any?()
    assert document |> LazyHTML.query("#asset-loaded-count") |> LazyHTML.text() =~ "1 of 12"
    assert document |> LazyHTML.query("#asset-list") |> Enum.any?()
  end

  defp filters do
    %{
      query: "anc",
      chains: ["Polygon"],
      chain_option_query: "",
      risks: ["Elevated"],
      risk_option_query: "",
      actions: ["manual_review"],
      action_option_query: "",
      operator_states: ["unreviewed"],
      operator_state_option_query: ""
    }
  end

  defp filter_form(filters) do
    Phoenix.Component.to_form(
      %{
        "query" => filters.query,
        "chains" => filters.chains,
        "chain_option_query" => filters.chain_option_query,
        "risks" => filters.risks,
        "risk_option_query" => filters.risk_option_query,
        "actions" => filters.actions,
        "action_option_query" => filters.action_option_query,
        "operator_states" => filters.operator_states,
        "operator_state_option_query" => filters.operator_state_option_query
      },
      as: :filters
    )
  end

  defp query_chip do
    %{
      id: "query-anc",
      field: "query",
      value: "anc",
      group: "Search",
      label: "anc",
      icon: "hero-magnifying-glass"
    }
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
      scenario: nil
    }
  end
end
