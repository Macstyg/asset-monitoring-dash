defmodule AssetMonitoringDashWeb.AssetLive.Components.AssetContextStripTest do
  use AssetMonitoringDashWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias AssetMonitoringDashWeb.AssetLive.Components.AssetContextStrip

  test "renders compact asset identity and signal context" do
    document =
      render_component(&AssetContextStrip.render/1, asset: asset())
      |> LazyHTML.from_fragment()

    assert document |> LazyHTML.query("#asset-context-strip") |> Enum.any?()
    assert document |> LazyHTML.query("#asset-context-chain") |> LazyHTML.text() =~ "Ethereum"
    assert document |> LazyHTML.query("#asset-context-game") |> LazyHTML.text() =~ "Embervale"
    assert document |> LazyHTML.query("#asset-context-rarity") |> LazyHTML.text() =~ "Mythic"
    assert document |> LazyHTML.query("#asset-context-type") |> LazyHTML.text() =~ "NFT"

    assert document |> LazyHTML.query("#asset-context-value") |> LazyHTML.text() =~
             "$18,612 collateral"

    assert document |> LazyHTML.query("#asset-context-loan") |> LazyHTML.text() =~
             "$15,900 borrowed"

    assert document |> LazyHTML.query("#asset-context-oracle") |> LazyHTML.text() =~ "Fresh"
    assert document |> LazyHTML.query("#asset-context-liquidity") |> LazyHTML.text() =~ "Deep"

    assert document |> LazyHTML.query("#asset-context-depth") |> LazyHTML.text() =~
             "$110,000 market depth"
  end

  defp asset do
    %{
      asset_type: "NFT",
      chain: "Ethereum",
      current_value_usd: 18_612,
      ecosystem: "Embervale",
      liquidity_status: "Deep",
      loan_value_usd: 15_900,
      market_depth_usd: 110_000,
      oracle_status: "Fresh",
      rarity: "Mythic"
    }
  end
end
