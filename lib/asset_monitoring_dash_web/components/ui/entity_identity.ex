defmodule AssetMonitoringDashWeb.UI.EntityIdentity do
  @moduledoc """
  Compact identity block with initials, name, and caption.
  """

  use Phoenix.Component

  alias AssetMonitoringDashWeb.UI.AssetIcon

  attr :asset_icon, :string, default: nil
  attr :caption, :string, required: true
  attr :class, :string, default: ""
  attr :initials, :string, default: nil
  attr :name, :string, required: true

  def render(assigns) do
    assigns =
      assign_new(assigns, :display_initials, fn -> assigns.initials || initials(assigns.name) end)

    ~H"""
    <div class={["flex min-w-0 items-center gap-3", @class]}>
      <AssetIcon.render icon={@asset_icon} fallback={@display_initials} />
      <div class="min-w-0">
        <p class="truncate text-sm font-semibold text-app-fg">{@name}</p>
        <p class="mt-1 truncate font-mono text-xs text-app-muted">{@caption}</p>
      </div>
    </div>
    """
  end

  defp initials(name) do
    name
    |> String.split(" ", trim: true)
    |> Enum.map(&String.first/1)
    |> Enum.take(2)
    |> Enum.join()
  end
end
