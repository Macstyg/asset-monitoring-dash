defmodule AssetMonitoringDashWeb.UI.AssetIcon do
  @moduledoc """
  Small inventory-style mark for fictional collateral assets.
  """

  use Phoenix.Component

  @asset_icons ~w(
    battle-pass
    dragon-helm
    drift-chassis
    ember-crown
    founder-parcel
    guild-charter
    mana-vault
    mech-core
    pulse-racer
    victory-crate
    void-skin
    warbeast
  )

  attr :class, :string, default: ""
  attr :fallback, :string, required: true
  attr :icon, :string, default: nil

  def render(assigns) do
    assigns = assign(assigns, :icon_path, asset_icon_path(assigns.icon))

    ~H"""
    <span
      aria-hidden="true"
      class={[
        "grid size-9 shrink-0 place-items-center rounded-app font-mono text-xs font-bold text-white shadow-[inset_0_1px_0_rgba(255,255,255,0.28)] ring-1 ring-inset",
        asset_icon_class(@icon),
        @class
      ]}
    >
      <img :if={@icon_path} src={@icon_path} alt="" class="size-5" />
      <span :if={is_nil(@icon_path)}>{@fallback}</span>
    </span>
    """
  end

  defp asset_icon_path(icon) when icon in @asset_icons, do: "/images/assets/#{icon}.svg"
  defp asset_icon_path(_icon), do: nil

  defp asset_icon_class("battle-pass"),
    do: "bg-linear-to-br from-sky-500 to-cyan-500 ring-sky-300/30"

  defp asset_icon_class("dragon-helm"),
    do: "bg-linear-to-br from-emerald-500 to-teal-600 ring-emerald-300/30"

  defp asset_icon_class("drift-chassis"),
    do: "bg-linear-to-br from-blue-500 to-indigo-600 ring-blue-300/30"

  defp asset_icon_class("ember-crown"),
    do: "bg-linear-to-br from-amber-500 to-rose-500 ring-amber-300/30"

  defp asset_icon_class("founder-parcel"),
    do: "bg-linear-to-br from-stone-500 to-amber-700 ring-amber-200/30"

  defp asset_icon_class("guild-charter"),
    do: "bg-linear-to-br from-lime-500 to-emerald-600 ring-lime-300/30"

  defp asset_icon_class("mana-vault"),
    do: "bg-linear-to-br from-violet-500 to-fuchsia-600 ring-violet-300/30"

  defp asset_icon_class("mech-core"),
    do: "bg-linear-to-br from-cyan-500 to-slate-700 ring-cyan-300/30"

  defp asset_icon_class("pulse-racer"),
    do: "bg-linear-to-br from-indigo-500 to-cyan-500 ring-indigo-300/30"

  defp asset_icon_class("victory-crate"),
    do: "bg-linear-to-br from-orange-500 to-yellow-500 ring-yellow-200/30"

  defp asset_icon_class("void-skin"),
    do: "bg-linear-to-br from-slate-600 to-purple-700 ring-purple-300/30"

  defp asset_icon_class("warbeast"),
    do: "bg-linear-to-br from-red-500 to-zinc-700 ring-red-300/30"

  defp asset_icon_class(_icon),
    do: "bg-linear-to-br from-app-accent-2 to-app-accent ring-white/20"
end
