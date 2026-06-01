defmodule AssetMonitoringDashWeb.UI.ChartTest do
  use AssetMonitoringDashWeb.ComponentCase, async: true

  alias AssetMonitoringDashWeb.UI.Chart

  test "renders an ECharts hook target with encoded chart options" do
    document =
      render_component(&Chart.render/1,
        id: "event-volume-chart",
        option: %{
          series: [
            %{type: "bar", data: [%{value: 3}]}
          ],
          xAxis: %{data: ["System"]},
          yAxis: %{type: "value"}
        }
      )
      |> LazyHTML.from_fragment()

    assert document |> LazyHTML.query(~s(#event-volume-chart[phx-hook="EChart"])) |> Enum.any?()
    assert document |> LazyHTML.query(~s(#event-volume-chart[phx-update="ignore"])) |> Enum.any?()

    assert document
           |> LazyHTML.query("#event-volume-chart")
           |> LazyHTML.attribute("data-chart-option")
           |> List.first()
           |> Jason.decode!()
           |> get_in(["series", Access.at(0), "type"]) == "bar"
  end
end
