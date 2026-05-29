defmodule AssetMonitoringDashWeb.UI.ChainIcon do
  @moduledoc """
  Small visual mark for blockchain networks.
  """

  use Phoenix.Component

  attr :chain, :string, required: true
  attr :class, :string, default: ""

  def render(assigns) do
    ~H"""
    <span
      aria-label={"#{@chain} chain"}
      title={@chain}
      class={[
        "grid size-9 shrink-0 place-items-center rounded-full border font-mono text-[0.68rem] font-bold shadow-[inset_0_0_0_4px_color-mix(in_oklch,var(--amd-bg),transparent_72%)]",
        chain_icon_class(@chain),
        @class
      ]}
    >
      <.chain_mark chain={@chain} />
    </span>
    """
  end

  attr :chain, :string, required: true

  defp chain_mark(%{chain: "Ethereum"} = assigns) do
    ~H"""
    <svg viewBox="0 0 24 24" class="size-5" aria-hidden="true">
      <path fill="currentColor" d="M12 2 5.5 12.2 12 9.2l6.5 3L12 2Z" opacity="0.82" />
      <path fill="currentColor" d="M12 10.5 5.5 13.5 12 17.2l6.5-3.7-6.5-3Z" />
      <path fill="currentColor" d="m12 18.5-6.5-3.7L12 22l6.5-7.2-6.5 3.7Z" opacity="0.72" />
    </svg>
    """
  end

  defp chain_mark(%{chain: "Polygon"} = assigns) do
    ~H"""
    <svg viewBox="0 0 24 24" class="size-5" aria-hidden="true">
      <path
        d="M8.2 8.1 4.6 10.2v4.2l3.6 2.1 3.6-2.1v-1.6l2.4 1.4v1.6l3.6 2.1 3.6-2.1v-4.2l-3.6-2.1-3.6 2.1v1.6l-2.4-1.4v-1.6L8.2 8.1Z"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linejoin="round"
      />
    </svg>
    """
  end

  defp chain_mark(%{chain: "Base"} = assigns) do
    ~H"""
    <span aria-hidden="true">B</span>
    """
  end

  defp chain_mark(%{chain: "Arbitrum"} = assigns) do
    ~H"""
    <svg viewBox="0 0 24 24" class="size-5" aria-hidden="true">
      <path
        d="M12 2 21 7v10l-9 5-9-5V7l9-5Z"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
      />
      <path
        d="m8 16 4-9 4 9m-5.8-3h3.6"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
      />
    </svg>
    """
  end

  defp chain_mark(%{chain: "Ronin"} = assigns) do
    ~H"""
    <span aria-hidden="true">R</span>
    """
  end

  defp chain_mark(%{chain: "Immutable"} = assigns) do
    ~H"""
    <span aria-hidden="true">IM</span>
    """
  end

  defp chain_mark(assigns) do
    ~H"""
    <span aria-hidden="true">{initial(@chain)}</span>
    """
  end

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
