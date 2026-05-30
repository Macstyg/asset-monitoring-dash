defmodule AssetMonitoringDashWeb.UI.LoadStatus do
  @moduledoc """
  Compact status line for paged or streamed collections.
  """

  use Phoenix.Component

  attr :count, :integer, required: true
  attr :hint, :string, default: "Scroll to load more"
  attr :hint_id, :string, default: nil
  attr :loaded_count, :integer, required: true
  attr :show_hint, :boolean, default: false
  attr :status_id, :string, required: true

  def render(assigns) do
    ~H"""
    <div class="mt-3 flex flex-wrap items-center gap-2 text-xs text-app-muted">
      <span id={@status_id} class="font-mono">
        {range_label(@loaded_count, @count)}
      </span>
      <span :if={@show_hint} id={@hint_id}>
        {@hint}
      </span>
    </div>
    """
  end

  defp range_label(0, count), do: "Showing 0 of #{count}"

  defp range_label(loaded_count, count) do
    "Showing 1-#{min(loaded_count, count)} of #{count}"
  end
end
