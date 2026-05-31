defmodule AssetMonitoringDashWeb.AssetLive.ReviewActionTest do
  use AssetMonitoringDashWeb.ConnCase, async: true

  alias AssetMonitoringDash.ReviewAudit
  alias AssetMonitoringDashWeb.AssetLive.ReviewAction

  test "builds a sanitized review form" do
    form =
      ReviewAction.form(%{
        "reason" => "unknown",
        "note" => "  #{String.duplicate("x", 220)}  "
      })

    assert form[:reason].value == "signal_reviewed"
    assert String.length(form[:note].value) == 180
  end

  test "builds review audit context with display reason labels" do
    assert %ReviewAudit{
             reason: "Oracle checked",
             note: "Floor feed verified."
           } =
             ReviewAction.audit_context(%{
               "reason" => "oracle_checked",
               "note" => "  Floor feed verified.  "
             })
  end

  test "exposes review reason options for the decision rail" do
    assert {"Signal reviewed", "signal_reviewed"} in ReviewAction.options()
    assert {"Borrower follow-up", "borrower_follow_up"} in ReviewAction.options()
  end
end
