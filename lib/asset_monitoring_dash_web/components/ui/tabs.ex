defmodule AssetMonitoringDashWeb.UI.Tabs do
  @moduledoc """
  Tab navigation primitive for switching between sibling panels.
  """

  use Phoenix.Component

  attr :active, :string, required: true
  attr :change_event, :string, required: true
  attr :class, :string, default: ""
  attr :id, :string, required: true
  attr :label, :string, default: "Tabs"
  attr :panel_id_prefix, :string, default: nil
  attr :tab_id_prefix, :string, default: nil
  attr :tabs, :list, required: true

  def render(assigns) do
    assigns =
      assigns
      |> assign_new(:resolved_tab_id_prefix, fn -> assigns.tab_id_prefix || assigns.id end)

    ~H"""
    <nav
      id={@id}
      aria-label={@label}
      role="tablist"
      class={["border-b border-app-border", @class]}
    >
      <div class="flex min-w-0 items-end gap-8 overflow-x-auto">
        <button
          :for={tab <- @tabs}
          id={tab_id(@resolved_tab_id_prefix, tab)}
          type="button"
          role="tab"
          aria-controls={panel_id(@panel_id_prefix, tab)}
          aria-selected={tab_value(tab) == @active}
          phx-click={@change_event}
          phx-value-tab={tab_value(tab)}
          class={[
            "relative -mb-px h-14 shrink-0 border-b-2 px-0.5 text-base font-semibold tracking-normal transition md:text-lg",
            "focus:outline-none focus:ring-2 focus:ring-app-accent/20 focus:ring-offset-2 focus:ring-offset-app-bg",
            tab_value(tab) == @active && "border-app-accent text-app-fg",
            tab_value(tab) != @active &&
              "border-transparent text-app-muted hover:border-app-border hover:text-app-fg"
          ]}
        >
          {tab_label(tab)}
        </button>
      </div>
    </nav>
    """
  end

  defp tab_id(prefix, tab), do: "#{prefix}-#{tab_value(tab)}"

  defp panel_id(nil, _tab), do: nil
  defp panel_id(prefix, tab), do: "#{prefix}-#{tab_value(tab)}"

  defp tab_value(%{value: value}), do: value
  defp tab_value(%{"value" => value}), do: value

  defp tab_label(%{label: label}), do: label
  defp tab_label(%{"label" => label}), do: label
end
