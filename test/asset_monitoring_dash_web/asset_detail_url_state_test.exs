defmodule AssetMonitoringDashWeb.AssetDetailURLStateTest do
  use ExUnit.Case, async: true

  alias AssetMonitoringDashWeb.AssetDetailURLState

  test "defaults to no persisted activity filters" do
    state = AssetDetailURLState.default()

    assert state.event_filters.sources == []
    assert state.event_filters.source_option_query == ""
    assert AssetDetailURLState.params(state) == %{}
  end

  test "loads selected activity sources from URL params" do
    state =
      AssetDetailURLState.from_params(%{
        "activity_sources" => "scenario,operator,unknown"
      })

    assert state.event_filters.sources == ["scenario", "operator"]
    assert AssetDetailURLState.params(state) == %{"activity_sources" => "scenario,operator"}
  end

  test "keeps local option search out of URL params" do
    state =
      AssetDetailURLState.new(%{
        sources: ["scenario"],
        source_option_query: " Oper "
      })

    assert state.event_filters.source_option_query == "oper"
    assert AssetDetailURLState.params(state) == %{"activity_sources" => "scenario"}
  end

  test "compares only URL-backed fields" do
    left =
      AssetDetailURLState.new(%{
        sources: ["scenario"],
        source_option_query: "sc"
      })

    right =
      AssetDetailURLState.new(%{
        sources: ["scenario"],
        source_option_query: ""
      })

    assert AssetDetailURLState.same_url_params?(left, right)
  end
end
