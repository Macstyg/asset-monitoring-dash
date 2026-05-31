defmodule AssetMonitoringDash.ReviewAuditTest do
  use ExUnit.Case, async: true

  alias AssetMonitoringDash.ReviewAudit

  test "normalizes audit context from atom-keyed params" do
    assert ReviewAudit.new(%{reason: " Oracle checked ", note: " Feed matched "}) ==
             %ReviewAudit{reason: "Oracle checked", note: "Feed matched"}
  end

  test "normalizes audit context from string-keyed params" do
    assert ReviewAudit.new(%{"reason" => " Liquidity checked ", "note" => nil}) ==
             %ReviewAudit{reason: "Liquidity checked", note: ""}
  end

  test "normalizes existing audit structs" do
    assert ReviewAudit.normalize(%ReviewAudit{
             reason: " Borrower follow-up ",
             note: " Call queued "
           }) ==
             %ReviewAudit{reason: "Borrower follow-up", note: "Call queued"}
  end

  test "falls back to an empty audit context for unsupported input" do
    assert ReviewAudit.normalize(:missing) == %ReviewAudit{reason: "", note: ""}
  end
end
