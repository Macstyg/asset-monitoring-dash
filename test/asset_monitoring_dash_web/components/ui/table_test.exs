defmodule AssetMonitoringDashWeb.UI.TableTest do
  use AssetMonitoringDashWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias AssetMonitoringDashWeb.ComponentFixtures

  test "renders sortable headers only for columns with sort keys" do
    document =
      render_component(&ComponentFixtures.sortable_table/1)
      |> LazyHTML.from_fragment()

    refute document
           |> LazyHTML.query("#positions-sort-asset")
           |> Enum.any?()

    assert document
           |> LazyHTML.query(
             ~s(button#positions-sort-value[phx-click="sort_assets"][phx-value-field="value"])
           )
           |> Enum.any?()

    assert document
           |> LazyHTML.query(
             ~s(button#positions-sort-ltv[phx-click="sort_assets"][phx-value-field="ltv"])
           )
           |> Enum.any?()
  end

  test "marks the active sortable header with the direction icon" do
    document =
      render_component(&ComponentFixtures.sortable_table/1)
      |> LazyHTML.from_fragment()

    assert document
           |> LazyHTML.query("#positions-sort-ltv .hero-chevron-down")
           |> Enum.any?()

    refute document
           |> LazyHTML.query("#positions-sort-value .hero-chevron-down")
           |> Enum.any?()
  end
end
