defmodule AssetMonitoringDashWeb.AssetLive.Components.RiskDriversTest do
  use AssetMonitoringDashWeb.ComponentCase, async: true

  alias AssetMonitoringDashWeb.AssetLive.Components.RiskDrivers

  test "renders risk explanation headline and reason metrics" do
    document =
      render_component(&RiskDrivers.render/1,
        risk_explanation: %{
          headline: "Collateral buffer needs attention.",
          reasons: [
            %{
              id: "ltv_pressure",
              label: "LTV pressure",
              detail: "Position is near review threshold.",
              metric: {:percent, 68.2},
              tone: :warning
            },
            %{
              id: "valuation_gap",
              label: "Valuation gap",
              detail: "Collateral value is below recent floor.",
              metric: {:usd, 1_240},
              tone: :danger
            }
          ]
        }
      )
      |> LazyHTML.from_fragment()

    assert document |> LazyHTML.query("#risk-explanation") |> Enum.any?()

    assert document |> LazyHTML.query("#risk-explanation-headline") |> LazyHTML.text() =~
             "Collateral buffer needs attention."

    assert document |> LazyHTML.query("#risk-reason-ltv_pressure") |> LazyHTML.text() =~ "68.2%"
    assert document |> LazyHTML.query("#risk-reason-valuation_gap") |> LazyHTML.text() =~ "$1,240"
  end
end
