defmodule AssetMonitoringDashWeb.UI.ThemeSwitch do
  @moduledoc """
  Light/dark theme switch backed by the app-wide root theme handler.
  """

  use Phoenix.Component

  import AssetMonitoringDashWeb.CoreComponents, only: [icon: 1]

  alias Phoenix.LiveView.JS

  attr :class, :string, default: ""
  attr :id, :string, default: "theme-toggle"
  attr :rest, :global

  def render(assigns) do
    ~H"""
    <div id={@id} class={["shrink-0", @class]} {@rest}>
      <button
        id={"#{@id}-dark"}
        type="button"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="dark"
        class="inline-flex h-11 items-center gap-2 rounded-app border border-app-border bg-app-surface px-3 text-sm font-semibold text-app-fg shadow-app-panel transition hover:border-app-accent/40 hover:bg-app-surface-2 focus:outline-none focus:ring-2 focus:ring-app-accent/20 [[data-theme=dark]_&]:hidden"
        aria-label="Switch to dark theme"
      >
        <.icon name="hero-moon" class="size-4 text-app-muted" />
        <span class="hidden sm:inline">Dark</span>
      </button>
      <button
        id={"#{@id}-light"}
        type="button"
        phx-click={JS.dispatch("phx:set-theme")}
        data-phx-theme="light"
        class="hidden h-11 items-center gap-2 rounded-app border border-app-border bg-app-surface px-3 text-sm font-semibold text-app-fg shadow-app-panel transition hover:border-app-accent/40 hover:bg-app-surface-2 focus:outline-none focus:ring-2 focus:ring-app-accent/20 [[data-theme=dark]_&]:inline-flex"
        aria-label="Switch to light theme"
      >
        <.icon name="hero-sun" class="size-4 text-app-muted" />
        <span class="hidden sm:inline">Light</span>
      </button>
    </div>
    """
  end
end
