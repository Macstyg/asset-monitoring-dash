defmodule AssetMonitoringDashWeb.UI.Tooltip do
  @moduledoc """
  DaisyUI-style tooltip primitive backed by local app styling.
  """

  use Phoenix.Component

  attr :class, :string, default: ""
  attr :id, :string, required: true
  attr :position, :atom, values: [:top, :bottom], default: :top
  attr :tip, :string, required: true
  attr :trigger_label, :string, default: "More information"

  slot :inner_block, required: true

  def render(assigns) do
    ~H"""
    <span
      id={@id}
      class={["amd-tooltip", position_class(@position), @class]}
      data-tip={@tip}
    >
      <button
        type="button"
        class="inline-flex items-center justify-center rounded-full text-app-muted transition hover:text-app-fg focus:outline-none focus:ring-2 focus:ring-app-accent/25"
        aria-label={@trigger_label}
        aria-describedby={"#{@id}-content"}
      >
        {render_slot(@inner_block)}
      </button>
      <span id={"#{@id}-content"} role="tooltip" class="amd-tooltip-content">
        {@tip}
      </span>
    </span>
    """
  end

  defp position_class(:top), do: "amd-tooltip-top"
  defp position_class(:bottom), do: "amd-tooltip-bottom"
end
