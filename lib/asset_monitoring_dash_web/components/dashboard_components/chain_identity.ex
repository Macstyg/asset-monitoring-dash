defmodule AssetMonitoringDashWeb.DashboardComponents.ChainIdentity do
  @moduledoc """
  Compact chain identity mark for asset table rows.
  """

  use Phoenix.Component

  alias AssetMonitoringDashWeb.UI.ChainIcon

  attr :chain, :string, required: true
  attr :class, :string, default: ""
  attr :ecosystem, :string, required: true

  def render(assigns) do
    ~H"""
    <div class={["flex min-w-0 items-center gap-3", @class]}>
      <ChainIcon.render chain={@chain} />

      <div class="min-w-0">
        <p class="truncate text-sm font-semibold text-app-fg">{@chain}</p>
        <p class="mt-1 truncate font-mono text-xs text-app-muted">{@ecosystem}</p>
      </div>
    </div>
    """
  end
end
