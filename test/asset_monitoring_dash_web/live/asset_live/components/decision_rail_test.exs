defmodule AssetMonitoringDashWeb.AssetLive.Components.DecisionRailTest do
  use AssetMonitoringDashWeb.ComponentCase, async: true

  alias AssetMonitoringDashWeb.AssetLive.Components.DecisionRail

  test "renders investigation, scenario, and operator decision sections" do
    document =
      render_component(&DecisionRail.render/1,
        asset: asset(),
        asset_shocked?: false,
        escalated: false,
        health_factor: "1.7",
        reason_options: [{"Signal reviewed", "signal_reviewed"}],
        review_action_form: review_action_form(),
        review_state: %{label: "Unreviewed", tone: :neutral},
        reviewed: false,
        risk_recommendation: %{
          id: :manual_review,
          label: "Manual review",
          tone: :warning,
          detail: "System recommends analyst review before trusting automation.",
          reasons: [%{id: :elevated_risk, label: "Elevated risk"}],
          next_step: "System recommends analyst review before trusting automation."
        }
      )
      |> LazyHTML.from_fragment()

    assert document |> LazyHTML.query("#asset-decision-rail") |> Enum.any?()
    assert document |> LazyHTML.query("#investigation-brief") |> Enum.any?()
    assert document |> LazyHTML.query("#asset-scenario-controls") |> Enum.any?()
    assert document |> LazyHTML.query("#review-action-form") |> Enum.any?()
  end

  defp review_action_form do
    Phoenix.Component.to_form(
      %{
        "reason" => "signal_reviewed",
        "note" => ""
      },
      as: :review_action
    )
  end

  defp asset do
    %{
      chain: "Polygon",
      liquidity_status: "Deep",
      ltv_percent: 59.7,
      oracle_status: "Fresh"
    }
  end
end
