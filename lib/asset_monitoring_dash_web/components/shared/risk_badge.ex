defmodule AssetMonitoringDashWeb.SharedComponents.RiskBadge do
  @moduledoc """
  Product mapping from asset risk bands to badge tones.
  """

  use Phoenix.Component

  alias AssetMonitoringDashWeb.UI.Badge

  attr :class, :string, default: ""
  attr :label, :string, required: true

  def render(assigns) do
    ~H"""
    <Badge.render class={@class} label={@label} tone={risk_tone(@label)} />
    """
  end

  defp risk_tone("Low"), do: :success
  defp risk_tone("Moderate"), do: :info
  defp risk_tone("Elevated"), do: :warning
  defp risk_tone("Critical"), do: :danger
  defp risk_tone(_label), do: :neutral
end
