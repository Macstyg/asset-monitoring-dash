defmodule AssetMonitoringDashWeb.UI.Badge do
  @moduledoc """
  Small status badge primitive.
  """

  use Phoenix.Component

  attr :class, :string, default: ""
  attr :label, :string, required: true
  attr :tone, :atom, values: [:neutral, :success, :info, :warning, :danger], default: :neutral
  attr :rest, :global

  def render(assigns) do
    ~H"""
    <span
      class={[
        "inline-flex w-fit rounded-full px-2.5 py-1 font-mono text-xs font-semibold ring-1 ring-inset",
        tone_class(@tone),
        @class
      ]}
      {@rest}
    >
      {@label}
    </span>
    """
  end

  defp tone_class(:success), do: "bg-app-accent/10 text-app-accent ring-app-accent/20"
  defp tone_class(:info), do: "bg-app-accent-2/10 text-app-accent-2 ring-app-accent-2/20"
  defp tone_class(:warning), do: "bg-app-warn/10 text-app-warn ring-app-warn/25"
  defp tone_class(:danger), do: "bg-app-danger/10 text-app-danger ring-app-danger/25"
  defp tone_class(:neutral), do: "bg-app-surface-2 text-app-muted ring-app-border"
end
