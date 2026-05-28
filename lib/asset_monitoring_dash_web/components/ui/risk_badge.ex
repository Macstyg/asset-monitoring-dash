defmodule AssetMonitoringDashWeb.UI.RiskBadge do
  @moduledoc """
  Visual treatment for asset risk bands.
  """

  use Phoenix.Component

  attr :class, :string, default: ""
  attr :label, :string, required: true

  def render(assigns) do
    ~H"""
    <span class={[
      "inline-flex rounded-full px-2.5 py-1 font-mono text-xs font-semibold ring-1 ring-inset",
      risk_badge_class(@label),
      @class
    ]}>
      {@label}
    </span>
    """
  end

  defp risk_badge_class("Low"), do: "bg-app-accent/10 text-app-accent ring-app-accent/20"

  defp risk_badge_class("Moderate"),
    do: "bg-app-accent-2/10 text-app-accent-2 ring-app-accent-2/20"

  defp risk_badge_class("Elevated"), do: "bg-app-warn/10 text-app-warn ring-app-warn/25"
  defp risk_badge_class("Critical"), do: "bg-app-danger/10 text-app-danger ring-app-danger/25"
end
