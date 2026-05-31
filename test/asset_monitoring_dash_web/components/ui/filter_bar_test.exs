defmodule AssetMonitoringDashWeb.UI.FilterBarTest do
  use AssetMonitoringDashWeb.ComponentCase, async: true

  alias AssetMonitoringDashWeb.UI.FilterBar

  test "active chips publish a generic remove-filter event payload" do
    chip = %{
      id: "chains-arbitrum",
      field: "chains",
      value: "Arbitrum",
      group: "Network",
      label: "Arbitrum",
      icon: :chain
    }

    document =
      render_component(&FilterBar.active_chip/1, chip: chip)
      |> LazyHTML.from_fragment()

    assert document
           |> LazyHTML.query(
             ~s(button#active-filter-chains-arbitrum[phx-click="remove_filter_value"])
           )
           |> Enum.any?()

    assert document
           |> LazyHTML.query(~s([phx-value-filter="chains"][phx-value-option="Arbitrum"]))
           |> Enum.any?()

    assert document
           |> LazyHTML.query(~s([aria-label="Arbitrum chain"]))
           |> Enum.any?()
  end
end
