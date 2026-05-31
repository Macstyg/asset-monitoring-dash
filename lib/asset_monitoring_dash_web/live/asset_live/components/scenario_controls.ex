defmodule AssetMonitoringDashWeb.AssetLive.Components.ScenarioControls do
  @moduledoc """
  Detail-page controls for applying and resetting demo asset scenarios.
  """

  use Phoenix.Component

  alias AssetMonitoringDashWeb.UI.Button
  alias AssetMonitoringDashWeb.UI.Card

  attr :active_scenario, :map, default: nil
  attr :asset_shocked?, :boolean, required: true
  attr :scenario_options, :list, required: true

  def render(assigns) do
    ~H"""
    <Card.surface id="asset-scenario-controls" class="grid gap-3">
      <div class="w-full">
        <p class="font-mono text-xs font-semibold uppercase tracking-[0.12em] text-app-muted">
          Scenario controls
        </p>
        <p class="mt-1 text-sm leading-6 text-app-muted">
          Stress this asset without changing the underlying demo fixture.
        </p>
        <p :if={@active_scenario} id="active-asset-scenario" class="mt-1 text-sm text-app-fg">
          Active: <span class="font-semibold">{@active_scenario.label}</span>
          <span class="text-app-muted">- {@active_scenario.description}</span>
        </p>
      </div>

      <div class="grid gap-2 sm:grid-cols-2">
        <div
          :for={scenario <- @scenario_options}
          class="rounded-app bg-app-bg/60 p-2 ring-1 ring-app-border"
        >
          <Button.render
            id={"apply-asset-scenario-#{scenario.id}"}
            phx-click="apply_asset_scenario"
            phx-value-scenario={scenario.id}
            title={scenario.description}
            disabled={@asset_shocked?}
            class="h-9 w-full justify-start px-3"
          >
            {scenario_button_label(scenario, @asset_shocked?, @active_scenario)}
          </Button.render>
          <p
            id={"asset-scenario-description-#{scenario.id}"}
            class="mt-2 text-xs leading-5 text-app-muted"
          >
            {scenario.description}
          </p>
        </div>
      </div>

      <Button.render
        id="apply-price-shock"
        phx-click="apply_price_shock"
        disabled={@asset_shocked?}
        class="hidden"
      >
        {price_shock_button_label(@asset_shocked?)}
      </Button.render>
      <Button.render
        id="reset-asset-scenario"
        phx-click="reset_asset_scenario"
        disabled={!@asset_shocked?}
        class="h-9 w-fit px-4"
      >
        Reset scenario
      </Button.render>
    </Card.surface>
    """
  end

  defp scenario_button_label(scenario, true, %{id: scenario_id}) when scenario.id == scenario_id,
    do: "#{scenario.label} applied"

  defp scenario_button_label(scenario, _asset_shocked?, _active_scenario), do: scenario.label

  defp price_shock_button_label(true), do: "Shock applied"
  defp price_shock_button_label(false), do: "Apply 12% price shock"
end
