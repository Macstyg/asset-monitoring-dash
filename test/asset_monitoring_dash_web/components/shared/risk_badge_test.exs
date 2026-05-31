defmodule AssetMonitoringDashWeb.SharedComponents.RiskBadgeTest do
  use AssetMonitoringDashWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias AssetMonitoringDashWeb.SharedComponents.RiskBadge

  test "maps known risk bands to badge tones" do
    low = render_component(&RiskBadge.render/1, label: "Low") |> LazyHTML.from_fragment()

    moderate =
      render_component(&RiskBadge.render/1, label: "Moderate") |> LazyHTML.from_fragment()

    elevated =
      render_component(&RiskBadge.render/1, label: "Elevated") |> LazyHTML.from_fragment()

    critical =
      render_component(&RiskBadge.render/1, label: "Critical") |> LazyHTML.from_fragment()

    assert LazyHTML.text(low) =~ "Low"
    assert low |> LazyHTML.query(".text-app-accent") |> Enum.any?()
    assert LazyHTML.text(moderate) =~ "Moderate"
    assert moderate |> LazyHTML.query(".text-app-accent-2") |> Enum.any?()
    assert LazyHTML.text(elevated) =~ "Elevated"
    assert elevated |> LazyHTML.query(".text-app-warn") |> Enum.any?()
    assert LazyHTML.text(critical) =~ "Critical"
    assert critical |> LazyHTML.query(".text-app-danger") |> Enum.any?()
  end

  test "falls back to a neutral badge for unknown risk bands" do
    document =
      render_component(&RiskBadge.render/1, label: "Unscored")
      |> LazyHTML.from_fragment()

    assert LazyHTML.text(document) =~ "Unscored"
    assert document |> LazyHTML.query(".text-app-muted") |> Enum.any?()
  end
end
