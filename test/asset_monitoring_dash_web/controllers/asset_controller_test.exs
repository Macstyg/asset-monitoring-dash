defmodule AssetMonitoringDashWeb.AssetControllerTest do
  use AssetMonitoringDashWeb.ConnCase, async: false

  test "GET /api/assets returns normalized monitored assets", %{conn: conn} do
    conn = get(conn, ~p"/api/assets")
    response = json_response(conn, 200)

    assert response["meta"]["count"] == 600
    assert response["meta"]["summary"]["visible_count"] == 600
    assert response["meta"]["summary"]["at_risk_count"] == 165

    assert %{
             "id" => id,
             "name" => "Aegis Dragon Helm",
             "icon" => "dragon-helm",
             "chain" => "Polygon",
             "ltv_percent" => 59.7,
             "risk_score" => 70,
             "risk_band" => "Elevated"
           } = List.first(response["data"])

    assert id == asset_id("asset-001")
  end

  test "GET /api/assets filters by risk band", %{conn: conn} do
    conn = get(conn, ~p"/api/assets", %{"risk_band" => "Critical"})
    response = json_response(conn, 200)

    asset_ids = Enum.map(response["data"], & &1["id"])

    assert response["meta"]["count"] == 14
    assert response["meta"]["filters"]["risks"] == ["Critical"]
    assert asset_id("asset-002") in asset_ids
    assert asset_id("asset-010") in asset_ids
    assert asset_id("asset-010-variant-005") in asset_ids
  end

  test "GET /api/assets combines query and chain filters", %{conn: conn} do
    conn = get(conn, ~p"/api/assets", %{"query" => "vault", "chain" => "Arbitrum"})
    response = json_response(conn, 200)

    asset_ids = Enum.map(response["data"], & &1["id"])

    assert response["meta"]["count"] == 50
    assert response["meta"]["filters"]["query"] == "vault"
    assert response["meta"]["filters"]["chains"] == ["Arbitrum"]
    assert asset_id("asset-005") in asset_ids
    assert asset_id("asset-005-variant-001") in asset_ids
  end
end
