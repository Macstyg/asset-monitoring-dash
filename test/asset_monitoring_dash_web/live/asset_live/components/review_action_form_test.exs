defmodule AssetMonitoringDashWeb.AssetLive.Components.ReviewActionFormTest do
  use AssetMonitoringDashWeb.ComponentCase, async: true

  alias AssetMonitoringDashWeb.AssetLive.Components.ReviewActionForm

  test "renders the operator decision form" do
    document =
      render_component(&ReviewActionForm.render/1,
        form: review_action_form(),
        reason_options: [{"Signal reviewed", "signal_reviewed"}],
        reviewed: false,
        escalated: false
      )
      |> LazyHTML.from_fragment()

    assert document |> LazyHTML.query("#review-action-panel") |> Enum.any?()

    assert document
           |> LazyHTML.query(
             ~s(form#review-action-form[phx-change="validate_review_action"][phx-submit="submit_review_action"])
           )
           |> Enum.any?()

    assert document |> LazyHTML.query("#review_action_reason") |> Enum.any?()
    assert document |> LazyHTML.query("#review_action_note") |> Enum.any?()

    assert document
           |> LazyHTML.query(~s(button#mark-asset-reviewed[value="reviewed"]))
           |> Enum.any?()

    assert document
           |> LazyHTML.query(~s(button#escalate-asset-review[value="escalated"]))
           |> Enum.any?()
  end

  test "disables actions that were already applied" do
    document =
      render_component(&ReviewActionForm.render/1,
        form: review_action_form(),
        reason_options: [{"Signal reviewed", "signal_reviewed"}],
        reviewed: true,
        escalated: true
      )
      |> LazyHTML.from_fragment()

    assert document |> LazyHTML.query("#mark-asset-reviewed[disabled]") |> Enum.any?()
    assert document |> LazyHTML.query("#escalate-asset-review[disabled]") |> Enum.any?()
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
end
