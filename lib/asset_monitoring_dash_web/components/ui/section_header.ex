defmodule AssetMonitoringDashWeb.UI.SectionHeader do
  @moduledoc """
  Reusable section title, description, and right-side control row.
  """

  use Phoenix.Component

  attr :description, :string, default: nil
  attr :title, :string, required: true

  slot :actions

  def render(assigns) do
    ~H"""
    <div class="flex flex-col gap-4 lg:flex-row lg:items-start lg:justify-between">
      <div class="min-w-0">
        <h2 class="text-base font-semibold text-app-fg">{@title}</h2>
        <p :if={@description} class="mt-1 text-sm text-app-muted">
          {@description}
        </p>
      </div>

      <div :if={@actions != []} class="flex shrink-0 flex-wrap items-center gap-2 lg:justify-end">
        {render_slot(@actions)}
      </div>
    </div>
    """
  end
end
