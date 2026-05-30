defmodule AssetMonitoringDashWeb.UI.Panel do
  @moduledoc """
  Framed surface primitive for dashboard sections.
  """

  use Phoenix.Component

  attr :class, :string, default: ""
  attr :rest, :global

  slot :inner_block, required: true

  def render(assigns) do
    ~H"""
    <section
      class={[
        "min-w-0 rounded-app border border-app-border bg-app-surface p-5 shadow-app-panel",
        @class
      ]}
      {@rest}
    >
      {render_slot(@inner_block)}
    </section>
    """
  end
end
