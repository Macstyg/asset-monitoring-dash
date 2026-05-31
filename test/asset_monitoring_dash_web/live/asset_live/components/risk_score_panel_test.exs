defmodule AssetMonitoringDashWeb.AssetLive.Components.RiskScorePanelTest do
  use AssetMonitoringDashWeb.ComponentCase, async: true

  alias AssetMonitoringDashWeb.AssetLive.Components.RiskScorePanel

  test "renders risk score value and meter width" do
    document =
      render_component(&RiskScorePanel.render/1, score: 68)
      |> LazyHTML.from_fragment()

    assert LazyHTML.text(document) =~ "Risk score"
    assert LazyHTML.text(document) =~ "68/100"

    assert document
           |> LazyHTML.query(~s(div[style="width: 68%"]))
           |> Enum.any?()
  end
end
