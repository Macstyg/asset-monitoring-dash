defmodule AssetMonitoringDashWeb.UI.Card do
  @moduledoc """
  Compact dashboard metric card.
  """

  use Phoenix.Component

  attr :class, :string, default: ""
  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :context, :string, default: nil
  attr :delta, :string, required: true
  attr :delta_tone, :atom, required: true
  attr :description, :string, default: nil
  attr :rest, :global

  def render(assigns) do
    ~H"""
    <article
      id={@id}
      class={[
        "group min-h-32 rounded-lg border border-slate-700/80 bg-[#11161d] px-5 py-4 shadow-[inset_0_1px_0_rgba(255,255,255,0.025),0_12px_30px_rgba(0,0,0,0.18)] transition duration-200 hover:-translate-y-0.5 hover:border-slate-500 hover:bg-[#141a22]",
        @class
      ]}
      {@rest}
    >
      <div class="flex items-center justify-between gap-4">
        <p class="font-mono text-xs font-semibold uppercase tracking-[0.14em] text-slate-500">
          {@label}
        </p>
        <p
          :if={@context}
          class="font-mono text-xs font-semibold uppercase tracking-[0.14em] text-slate-500"
        >
          {@context}
        </p>
      </div>

      <p class="mt-5 truncate text-4xl font-bold leading-none tracking-normal text-slate-100 md:text-5xl">
        {@value}
      </p>

      <div class={[
        "mt-5 flex items-center gap-2 font-mono text-sm font-semibold leading-5",
        signal_class(@delta_tone)
      ]}>
        <span aria-hidden="true">{signal_marker(@delta_tone)}</span>
        <p class="truncate">
          {@delta}<span :if={@description}> {@description}</span>
        </p>
      </div>
    </article>
    """
  end

  defp signal_class(:positive), do: "text-green-400"
  defp signal_class(:negative), do: "text-red-400"
  defp signal_class(:warning), do: "text-amber-400"
  defp signal_class(:neutral), do: "text-slate-400"

  defp signal_marker(:positive), do: "▲"
  defp signal_marker(:negative), do: "▼"
  defp signal_marker(:warning), do: "▲"
  defp signal_marker(:neutral), do: "•"
end
