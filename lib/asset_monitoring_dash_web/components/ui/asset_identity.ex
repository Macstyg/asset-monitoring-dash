defmodule AssetMonitoringDashWeb.UI.AssetIdentity do
  @moduledoc """
  Compact identity block for monitored collateral assets.
  """

  use Phoenix.Component

  attr :caption, :string, required: true
  attr :class, :string, default: ""
  attr :initials, :string, default: nil
  attr :name, :string, required: true

  def render(assigns) do
    assigns =
      assign_new(assigns, :display_initials, fn -> assigns.initials || initials(assigns.name) end)

    ~H"""
    <div class={["flex min-w-0 items-center gap-3", @class]}>
      <div class="grid size-9 shrink-0 place-items-center rounded-app bg-linear-to-br from-app-accent-2 to-app-accent font-mono text-xs font-bold text-app-primary-fg">
        {@display_initials}
      </div>
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
