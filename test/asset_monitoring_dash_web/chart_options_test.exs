defmodule AssetMonitoringDashWeb.ChartOptionsTest do
  use ExUnit.Case, async: true

  alias AssetMonitoringDashWeb.ChartOptions

  test "builds portfolio value trend options with formatted tooltip values" do
    option =
      ChartOptions.portfolio_value_trend([
        %{label: "1d", value: Decimal.new("1200000"), tooltip_value: "$1,200,000"},
        %{label: "Now", value: Decimal.new("1500000"), tooltip_value: "$1,500,000"}
      ])

    assert get_in(option, [:tooltip, :titlePrefix]) == "Snapshot"
    assert get_in(option, [:series, Access.at(0), :name]) == "Collateral value"

    assert get_in(option, [:series, Access.at(0), :data, Access.at(0), :tooltipValue]) ==
             "$1,200,000"

    assert get_in(option, [:series, Access.at(0), :data, Access.at(1), :value]) == 1.5
  end

  test "builds event volume options from source buckets" do
    option =
      ChartOptions.event_volume(
        [
          %{label: "-15s", sources: %{"system" => 2}},
          %{label: "now", sources: %{"scenario" => 1}}
        ],
        [
          %{value: "system", label: "System", tone: :info},
          %{value: "scenario", label: "Scenario", tone: :warning}
        ]
      )

    assert get_in(option, [:tooltip, :titlePrefix]) == "Window"
    assert get_in(option, [:xAxis, :data]) == ["-15s", "now"]
    assert get_in(option, [:series, Access.at(0), :data]) == [2, 0]
    assert get_in(option, [:series, Access.at(1), :data]) == [0, 1]
  end

  test "builds risk pressure options with collateral tooltip values" do
    option =
      ChartOptions.risk_pressure([
        %{
          label: "Critical",
          tone: :danger,
          collateral_value_usd: Decimal.new("1800000")
        }
      ])

    assert get_in(option, [:tooltip, :titlePrefix]) == "Risk tier"
    assert get_in(option, [:series, Access.at(0), :type]) == "pie"

    assert get_in(option, [:series, Access.at(0), :data, Access.at(0), :tooltipValue]) ==
             "$1,800,000"
  end

  test "builds asset LTV trend options with risk threshold lines" do
    option =
      ChartOptions.asset_ltv_trend([
        %{label: "6d", value: Decimal.new("56.5")},
        %{label: "5d", value: Decimal.new("58.1")},
        %{label: "Now", value: Decimal.new("59.7")}
      ])

    assert get_in(option, [:tooltip, :titlePrefix]) == "Observation"
    assert get_in(option, [:series, Access.at(0), :name]) == "LTV"
    assert get_in(option, [:yAxis, :axisLabel, :formatter]) == "{value}%"

    assert option
           |> get_in([:series, Access.at(0), :markLine, :data])
           |> Enum.map(& &1.name) == [
             "60% Watch",
             "75% Review",
             "80% Liquidation candidate"
           ]
  end
end
