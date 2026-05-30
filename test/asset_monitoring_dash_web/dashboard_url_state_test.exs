defmodule AssetMonitoringDashWeb.DashboardURLStateTest do
  use ExUnit.Case, async: true

  alias AssetMonitoringDash.Assets
  alias AssetMonitoringDashWeb.DashboardURLState

  test "defaults to the unfiltered asset monitor state" do
    state = DashboardURLState.from_params(%{})

    assert state == DashboardURLState.default()
    assert state.filters == Assets.default_filters()
    assert state.sort == %{field: :ltv, direction: :desc}
    assert DashboardURLState.params(state) == %{}
  end

  test "parses URL filters and sort into an explicit state struct" do
    state =
      DashboardURLState.from_params(%{
        "query" => " Mech ",
        "chains" => "Arbitrum,Base",
        "risks" => "Critical",
        "actions" => "manual_review",
        "operator_states" => "escalated",
        "sort" => "value",
        "dir" => "asc"
      })

    assert %DashboardURLState{} = state
    assert state.filters.query == "mech"
    assert state.filters.chains == ["Arbitrum", "Base"]
    assert state.filters.risks == ["Critical"]
    assert state.filters.actions == ["manual_review"]
    assert state.filters.operator_states == ["escalated"]
    assert state.sort == %{field: :value, direction: :asc}
  end

  test "serializes only shareable asset monitor params" do
    filters = %{
      Assets.default_filters()
      | query: "mech",
        chains: ["Arbitrum", "Base"],
        risks: ["Critical"],
        action_option_query: "liquid"
    }

    state = DashboardURLState.new(filters, %{field: :value, direction: :asc})

    assert DashboardURLState.params(state) == %{
             "query" => "mech",
             "chains" => "Arbitrum,Base",
             "risks" => "Critical",
             "sort" => "value",
             "dir" => "asc"
           }
  end

  test "falls back to safe sort values when URL params are unknown" do
    state = DashboardURLState.from_params(%{"sort" => "unknown", "dir" => "sideways"})

    assert state.sort == DashboardURLState.default_sort()
  end

  test "toggles sorting from the current explicit state" do
    state = DashboardURLState.default()

    assert DashboardURLState.next_sort(state, "ltv").sort == %{field: :ltv, direction: :asc}
    assert DashboardURLState.next_sort(state, "asset").sort == %{field: :asset, direction: :asc}
  end

  test "compares only URL-backed filters" do
    left =
      DashboardURLState.default()
      |> DashboardURLState.with_filters(%{
        Assets.default_filters()
        | chain_option_query: "eth"
      })

    right = DashboardURLState.default()

    assert DashboardURLState.same_filter_params?(left, right)
  end

  test "removes selected filter values from state" do
    state =
      Assets.default_filters()
      |> Map.put(:chains, ["Arbitrum", "Base"])
      |> DashboardURLState.new(DashboardURLState.default_sort())
      |> DashboardURLState.remove_filter_value(:chains, "Base")

    assert state.filters.chains == ["Arbitrum"]
  end
end
