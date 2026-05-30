defmodule AssetMonitoringDashWeb.ComponentFixtures do
  @moduledoc false

  use AssetMonitoringDashWeb, :html

  alias AssetMonitoringDashWeb.UI.Table

  def sortable_table(assigns) do
    assigns =
      assign_new(assigns, :rows, fn ->
        [
          {"row-alpha", %{id: "alpha", name: "Alpha"}},
          {"row-beta", %{id: "beta", name: "Beta"}}
        ]
      end)

    ~H"""
    <Table.render
      id="positions"
      label="Positions"
      grid_class="grid-cols-3"
      row_class="lg:grid-cols-3"
      rows={@rows}
      sort_direction={:desc}
      sort_event="sort_assets"
      sort_field={:ltv}
    >
      <:col>Asset</:col>
      <:col align={:right} sort_key="value">Value</:col>
      <:col align={:right} sort_key="ltv">LTV</:col>

      <:empty>No positions</:empty>

      <:row :let={asset}>
        <Table.cell label="Asset">{asset.name}</Table.cell>
        <Table.cell label="Value" align={:right}>$1</Table.cell>
        <Table.cell label="LTV" align={:right}>1%</Table.cell>
      </:row>
    </Table.render>
    """
  end
end
