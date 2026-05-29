defmodule AssetMonitoringDashWeb.UI.Button do
  @moduledoc """
  Button primitive for dashboard actions and compact controls.
  """

  use Phoenix.Component

  attr :active, :boolean, default: false
  attr :class, :string, default: ""
  attr :type, :string, default: "button"
  attr :rest, :global

  slot :inner_block, required: true

  def render(assigns) do
    ~H"""
    <button
      type={@type}
      class={[
        "inline-flex items-center justify-center rounded-full border px-3 py-1.5 text-xs font-semibold transition disabled:cursor-not-allowed disabled:opacity-50",
        state_class(@active),
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  defp state_class(true), do: "border-app-accent/35 bg-app-accent/10 text-app-accent"

  defp state_class(false),
    do:
      "border-app-border bg-app-surface-2 text-app-muted hover:border-app-accent/50 hover:text-app-fg"
end
