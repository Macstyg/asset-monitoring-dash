defmodule AssetMonitoringDashWeb.AssetLive.Components.RelatedAssets do
  @moduledoc """
  Related asset navigation for the inspection workflow.
  """

  use AssetMonitoringDashWeb, :html

  alias AssetMonitoringDashWeb.Formatters
  alias AssetMonitoringDashWeb.UI.Badge
  alias AssetMonitoringDashWeb.UI.Card
  alias AssetMonitoringDashWeb.UI.ChainIcon

  attr :activity_sources, :list, default: []
  attr :demo_story?, :boolean, default: false
  attr :focus, :string, default: "overview"
  attr :related_assets, :list, required: true
  attr :return_to, :string, required: true

  def render(assigns) do
    ~H"""
    <Card.surface id="related-assets">
      <div>
        <h2 class="text-base font-semibold text-app-fg">Related assets</h2>
        <p class="mt-1 text-sm text-app-muted">
          Same chain, game, or risk band for faster review triage.
        </p>
      </div>

      <div class="mt-4 grid gap-2">
        <.link
          :for={related_asset <- @related_assets}
          id={"related-asset-#{Map.get(related_asset, :dom_id, related_asset.id)}"}
          navigate={
            asset_detail_path(
              related_asset.id,
              @return_to,
              @activity_sources,
              @focus,
              @demo_story?
            )
          }
          class="grid min-w-0 grid-cols-[auto_minmax(0,1fr)_auto] items-center gap-3 rounded-app border border-app-border bg-app-surface-2 px-3 py-3 transition hover:border-app-accent/40 hover:bg-app-bg"
        >
          <ChainIcon.render chain={related_asset.chain} size="size-9" />
          <span class="min-w-0">
            <span class="block truncate text-sm font-semibold text-app-fg">
              {related_asset.name}
            </span>
            <span class="mt-0.5 block truncate font-mono text-xs text-app-muted">
              {related_asset.chain} · {related_asset.ecosystem}
            </span>
          </span>
          <span class="text-right">
            <Badge.render
              id={"related-asset-risk-#{Map.get(related_asset, :dom_id, related_asset.id)}"}
              label={related_asset.risk_band}
              tone={risk_tone(related_asset.risk_band)}
            />
            <span class="mt-1 block font-mono text-xs text-app-muted">
              {Formatters.ltv(related_asset.ltv_percent)}
            </span>
          </span>
        </.link>

        <div
          :if={@related_assets == []}
          id="related-assets-empty"
          class="rounded-app border border-dashed border-app-border bg-app-surface-2 px-4 py-6 text-center text-sm text-app-muted"
        >
          No nearby assets in this demo set.
        </div>
      </div>
    </Card.surface>
    """
  end

  defp asset_detail_path(asset_id, return_to, activity_sources, focus, demo_story?) do
    params =
      %{}
      |> put_return_to(return_to)
      |> put_activity_sources(activity_sources)
      |> put_focus(focus)
      |> put_demo_story(demo_story?)

    case params do
      empty when empty == %{} -> ~p"/assets/#{asset_id}"
      params -> ~p"/assets/#{asset_id}?#{params}"
    end
  end

  defp put_return_to(params, "/"), do: params
  defp put_return_to(params, return_to), do: Map.put(params, "return_to", return_to)

  defp put_activity_sources(params, []), do: params

  defp put_activity_sources(params, activity_sources) do
    Map.put(params, "activity_sources", Enum.join(activity_sources, ","))
  end

  defp put_focus(params, "overview"), do: params
  defp put_focus(params, focus), do: Map.put(params, "focus", focus)

  defp put_demo_story(params, true), do: Map.put(params, "demo", "story")
  defp put_demo_story(params, false), do: params

  defp risk_tone("Low"), do: :success
  defp risk_tone("Moderate"), do: :info
  defp risk_tone("Elevated"), do: :warning
  defp risk_tone("Critical"), do: :danger
  defp risk_tone(_risk), do: :neutral
end
