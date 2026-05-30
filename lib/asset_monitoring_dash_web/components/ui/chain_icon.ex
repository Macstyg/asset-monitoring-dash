defmodule AssetMonitoringDashWeb.UI.ChainIcon do
  @moduledoc """
  Small visual mark for blockchain networks.
  """

  use Phoenix.Component

  attr :chain, :string, required: true
  attr :class, :string, default: ""
  attr :size, :string, default: "size-9"

  def render(assigns) do
    ~H"""
    <span
      aria-label={"#{@chain} chain"}
      title={@chain}
      class={[
        "grid shrink-0 place-items-center overflow-hidden rounded-full border font-mono text-[0.68rem] font-bold shadow-[inset_0_0_0_4px_color-mix(in_oklch,var(--amd-bg),transparent_72%)]",
        @size,
        chain_icon_class(@chain),
        @class
      ]}
    >
      <.chain_mark chain={@chain} />
    </span>
    """
  end

  attr :chain, :string, required: true

  defp chain_mark(assigns) do
    assigns = assign(assigns, :icon_path, chain_icon_path(assigns.chain))

    ~H"""
    <img
      :if={@icon_path}
      src={@icon_path}
      alt=""
      aria-hidden="true"
      class="size-full rounded-full object-cover"
    />
    <span :if={is_nil(@icon_path)} aria-hidden="true">{initial(@chain)}</span>
    """
  end

  defp chain_icon_path("Arbitrum"), do: "/images/chains/arbitrum.svg"
  defp chain_icon_path("Base"), do: "/images/chains/base.svg"
  defp chain_icon_path("Ethereum"), do: "/images/chains/ethereum.svg"
  defp chain_icon_path("Immutable"), do: "/images/chains/immutable.svg"
  defp chain_icon_path("Polygon"), do: "/images/chains/polygon.svg"
  defp chain_icon_path("Ronin"), do: "/images/chains/ronin.svg"
  defp chain_icon_path(_chain), do: nil

  defp chain_icon_class("Ethereum"), do: "border-slate-400/30 bg-slate-100 text-slate-700"
  defp chain_icon_class("Polygon"), do: "border-violet-400/30 bg-violet-100 text-violet-700"
  defp chain_icon_class("Base"), do: "border-blue-400/30 bg-blue-100 text-blue-700"
  defp chain_icon_class("Arbitrum"), do: "border-sky-400/30 bg-sky-100 text-sky-700"
  defp chain_icon_class("Ronin"), do: "border-cyan-400/30 bg-cyan-100 text-cyan-700"
  defp chain_icon_class("Immutable"), do: "border-teal-400/30 bg-teal-100 text-teal-700"
  defp chain_icon_class(_chain), do: "border-app-border bg-app-surface-2 text-app-muted"

  defp initial(chain) do
    chain
    |> String.first()
    |> String.upcase()
  end
end
