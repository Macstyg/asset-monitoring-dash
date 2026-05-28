defmodule AssetMonitoringDash.DemoDataTest do
  use ExUnit.Case, async: true

  alias AssetMonitoringDash.DemoData

  test "portfolio snapshot exposes the first dashboard metrics" do
    snapshot = DemoData.portfolio_snapshot()

    assert snapshot.total_collateral_value_usd > 0
    assert snapshot.active_loans > 0
    assert snapshot.weighted_apy_percent > 0
    assert snapshot.risk_score in 0..100
    assert is_binary(snapshot.risk_band)
  end

  test "monitored assets expose the first asset monitor contract" do
    assets = DemoData.monitored_assets()

    assert length(assets) == 12

    assert Enum.all?(assets, fn asset ->
             is_binary(asset.id) and
               is_binary(asset.name) and
               is_binary(asset.asset_type) and
               is_binary(asset.chain) and
               is_binary(asset.ecosystem) and
               is_binary(asset.rarity) and
               is_integer(asset.floor_price_usd) and
               is_integer(asset.current_value_usd) and
               is_integer(asset.loan_value_usd) and
               is_float(asset.ltv_percent) and
               asset.risk_score in 0..100 and
               asset.risk_band in ["Low", "Moderate", "Elevated", "Critical"]
           end)
  end

  test "monitored assets include useful filter variety" do
    assets = DemoData.monitored_assets()

    assert assets |> Enum.map(& &1.chain) |> Enum.uniq() |> length() >= 4
    assert assets |> Enum.map(& &1.ecosystem) |> Enum.uniq() |> length() >= 4

    assert Enum.any?(assets, &(&1.risk_band == "Low"))
    assert Enum.any?(assets, &(&1.risk_band == "Moderate"))
    assert Enum.any?(assets, &(&1.risk_band == "Elevated"))
    assert Enum.any?(assets, &(&1.risk_band == "Critical"))
  end

  test "live events expose the first event feed contract" do
    events = DemoData.live_events()

    assert length(events) == 5

    assert Enum.all?(events, fn event ->
             is_binary(event.id) and
               is_binary(event.time_label) and
               is_binary(event.title) and
               is_binary(event.detail) and
               is_binary(event.chain) and
               is_binary(event.status) and
               event.tone in [:neutral, :success, :warning, :danger]
           end)

    assert Enum.any?(events, &(&1.tone == :danger))
    assert Enum.any?(events, &(&1.title == "Floor oracle moved"))
  end
end
