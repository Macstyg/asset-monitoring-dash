defmodule AssetMonitoringDashWeb.AssetLive.ReviewAction do
  @moduledoc """
  Form and audit helpers for asset detail review actions.
  """

  import Phoenix.Component, only: [to_form: 2]

  alias AssetMonitoringDash.ReviewAudit

  @default_reason "signal_reviewed"

  def options do
    [
      {"Signal reviewed", "signal_reviewed"},
      {"Oracle checked", "oracle_checked"},
      {"Liquidity checked", "liquidity_checked"},
      {"Borrower follow-up", "borrower_follow_up"}
    ]
  end

  def default_params, do: %{"reason" => @default_reason, "note" => ""}

  def form(params \\ default_params()) do
    to_form(
      %{
        "reason" => reason_value(Map.get(params, "reason")),
        "note" => note(Map.get(params, "note"))
      },
      as: :review_action
    )
  end

  def audit_context(params) do
    ReviewAudit.new(%{
      reason: reason_label(Map.get(params, "reason")),
      note: note(Map.get(params, "note"))
    })
  end

  defp reason_value(reason) do
    allowed_values = Enum.map(options(), fn {_label, value} -> value end)

    case reason in allowed_values do
      true -> reason
      false -> @default_reason
    end
  end

  defp reason_label(reason) do
    reason = reason_value(reason)

    options()
    |> Enum.find_value(fn
      {label, ^reason} -> label
      {_label, _value} -> nil
    end)
  end

  defp note(nil), do: ""

  defp note(note) do
    note
    |> String.trim()
    |> String.slice(0, 180)
  end
end
