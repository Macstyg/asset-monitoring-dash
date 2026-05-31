defmodule AssetMonitoringDashWeb.DashboardComponents.RelatedAssetsTest do
  use AssetMonitoringDashWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias AssetMonitoringDashWeb.DashboardComponents.RelatedAssets

  test "renders related asset links with detail URL state" do
    document =
      render_component(&RelatedAssets.render/1,
        activity_sources: ["scenario"],
        focus: "activity",
        related_assets: [related_asset()],
        return_to: "/?query=mech"
      )
      |> LazyHTML.from_fragment()

    assert document |> LazyHTML.query("#related-assets") |> Enum.any?()
    assert document |> LazyHTML.query("#related-asset-asset-009") |> Enum.any?()

    [href] =
      document
      |> LazyHTML.query("#related-asset-asset-009")
      |> LazyHTML.attribute("href")

    uri = URI.parse(href)
    params = URI.decode_query(uri.query)

    assert uri.path == "/assets/asset-009"
    assert params["activity_sources"] == "scenario"
    assert params["focus"] == "activity"
    assert params["return_to"] == "/?query=mech"
  end

  test "renders an empty related asset state" do
    document =
      render_component(&RelatedAssets.render/1,
        related_assets: [],
        return_to: "/"
      )
      |> LazyHTML.from_fragment()

    assert document |> LazyHTML.query("#related-assets-empty") |> Enum.any?()
  end

  defp related_asset do
    %{
      id: "asset-009",
      name: "Moonwell Guild Charter",
      chain: "Polygon",
      ecosystem: "Moonwell Tactics",
      risk_band: "Moderate",
      ltv_percent: 59.8
    }
  end
end
