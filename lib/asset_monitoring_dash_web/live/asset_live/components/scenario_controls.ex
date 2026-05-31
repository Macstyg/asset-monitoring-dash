defmodule AssetMonitoringDashWeb.AssetLive.Components.ScenarioControls do
  @moduledoc """
  Detail-page controls for applying and resetting demo asset scenarios.
  """

  use Phoenix.Component

  alias AssetMonitoringDashWeb.UI.Button
  alias AssetMonitoringDashWeb.UI.Card

  attr :asset_shocked?, :boolean, required: true

  def render(assigns) do
    ~H"""
    <Card.surface id="asset-scenario-controls" class="flex flex-wrap gap-2">
      <div class="w-full">
        <p class="font-mono text-xs font-semibold uppercase tracking-[0.12em] text-app-muted">
          Scenario controls
        </p>
        <p class="mt-1 text-sm leading-6 text-app-muted">
          Stress this asset without changing the underlying demo fixture.
        </p>
      </div>

      <Button.render
        id="apply-price-shock"
        phx-click="apply_price_shock"
        disabled={@asset_shocked?}
        class="h-9 px-4"
      >
        {price_shock_button_label(@asset_shocked?)}
      </Button.render>
      <Button.render
        id="reset-asset-scenario"
        phx-click="reset_asset_scenario"
        disabled={!@asset_shocked?}
        class="h-9 px-4"
      >
        Reset scenario
      </Button.render>
    </Card.surface>
    """
  end

  defp price_shock_button_label(true), do: "Shock applied"
  defp price_shock_button_label(false), do: "Apply 12% price shock"
end
