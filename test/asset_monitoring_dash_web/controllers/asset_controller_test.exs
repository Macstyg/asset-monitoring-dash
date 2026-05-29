defmodule AssetMonitoringDashWeb.AssetControllerTest do
  use AssetMonitoringDashWeb.ConnCase, async: true

  test "GET /api/assets returns normalized monitored assets", %{conn: conn} do
    conn = get(conn, ~p"/api/assets")
    response = json_response(conn, 200)

    assert response["meta"]["count"] == 12
    assert response["meta"]["summary"]["visible_count"] == 12
    assert response["meta"]["summary"]["at_risk_count"] == 6

    assert %{
             "id" => "asset-001",
             "name" => "Aegis Dragon Helm",
             "chain" => "Polygon",
             "ltv_percent" => 59.7,
             "risk_score" => 70,
             "risk_band" => "Elevated"
           } = List.first(response["data"])
  end

  test "GET /api/assets filters by risk band", %{conn: conn} do
    conn = get(conn, ~p"/api/assets", %{"risk_band" => "Critical"})
    response = json_response(conn, 200)

    assert response["meta"]["count"] == 2
    assert response["meta"]["filters"]["risk"] == "Critical"
    assert Enum.map(response["data"], & &1["id"]) == ["asset-002", "asset-010"]
  end

  test "GET /api/assets combines query and chain filters", %{conn: conn} do
    conn = get(conn, ~p"/api/assets", %{"query" => "vault", "chain" => "Arbitrum"})
    response = json_response(conn, 200)

    assert response["meta"]["count"] == 1
    assert response["meta"]["filters"]["query"] == "vault"
    assert response["meta"]["filters"]["chain"] == "Arbitrum"
    assert [%{"id" => "asset-005"}] = response["data"]
  end
end
