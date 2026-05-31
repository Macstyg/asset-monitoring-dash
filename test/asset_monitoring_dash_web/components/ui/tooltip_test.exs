defmodule AssetMonitoringDashWeb.UI.TooltipTest do
  use AssetMonitoringDashWeb.ComponentCase, async: true

  alias AssetMonitoringDashWeb.UI.Tooltip

  test "renders a DaisyUI-style data-tip wrapper with accessible tooltip content" do
    document =
      render_component(&Tooltip.render/1,
        id: "ltv-help",
        tip: "Loan-to-value: borrowed amount divided by current collateral value.",
        trigger_label: "Explain LTV",
        inner_block: [%{inner_block: fn _, _ -> "?" end}]
      )
      |> LazyHTML.from_fragment()

    assert document
           |> LazyHTML.query(
             ~s(#ltv-help.amd-tooltip[data-tip="Loan-to-value: borrowed amount divided by current collateral value."])
           )
           |> Enum.any?()

    assert document
           |> LazyHTML.query(
             ~s(button[aria-label="Explain LTV"][aria-describedby="ltv-help-content"])
           )
           |> Enum.any?()

    assert document
           |> LazyHTML.query(~s(#ltv-help-content[role="tooltip"]))
           |> LazyHTML.text() =~ "Loan-to-value"
  end
end
