defmodule AssetMonitoringDashWeb.UI.CardTest do
  use AssetMonitoringDashWeb.ComponentCase, async: true

  alias AssetMonitoringDashWeb.UI.Card

  test "separates metric delta and description text" do
    document =
      render_component(&Card.render/1,
        id: "metric-card",
        label: "Collateral value",
        value: "$3.5M",
        delta: "0.0%",
        delta_tone: :neutral,
        description: "monitored collateral"
      )
      |> LazyHTML.from_fragment()

    assert document |> LazyHTML.query("#metric-card") |> LazyHTML.text() =~
             "0.0% monitored collateral"
  end
end
