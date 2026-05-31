defmodule AssetMonitoringDashWeb.AssetLive.Components.ReviewWorkflowPanelTest do
  use AssetMonitoringDashWeb.ComponentCase, async: true

  alias AssetMonitoringDashWeb.AssetLive.Components.ReviewWorkflowPanel

  test "renders system recommendation and operator state with recommendation help" do
    document =
      render_component(&ReviewWorkflowPanel.render/1,
        recommendation: %{
          label: "Manual review",
          tone: :warning,
          detail: "System recommends analyst review before trusting automation.",
          reasons: [
            %{id: :elevated_risk, label: "Elevated risk", detail: "Risk score is above normal."}
          ]
        },
        review_state: %{
          label: "Unreviewed",
          tone: :neutral,
          detail: "No operator decision has been recorded."
        }
      )
      |> LazyHTML.from_fragment()

    assert document |> LazyHTML.query("#review-workflow-panel") |> Enum.any?()
    assert document |> LazyHTML.query("#system-recommendation-tooltip") |> Enum.any?()

    assert document |> LazyHTML.query("#risk-recommendation-label") |> LazyHTML.text() =~
             "Manual review"

    assert document |> LazyHTML.query("#operator-review-state-label") |> LazyHTML.text() =~
             "Unreviewed"
  end
end
