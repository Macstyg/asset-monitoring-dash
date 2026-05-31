defmodule AssetMonitoringDashWeb.UI.ChainIconTest do
  use AssetMonitoringDashWeb.ComponentCase, async: true

  alias AssetMonitoringDashWeb.UI.ChainIcon

  @chain_icons %{
    "Arbitrum" => "arbitrum.svg",
    "Base" => "base.svg",
    "Ethereum" => "ethereum.svg",
    "Immutable" => "immutable.svg",
    "Polygon" => "polygon.svg",
    "Ronin" => "ronin.svg"
  }

  test "renders a local SVG image for every supported network value" do
    for {chain, filename} <- @chain_icons do
      document =
        render_component(&ChainIcon.render/1, chain: chain)
        |> LazyHTML.from_fragment()

      assert document
             |> LazyHTML.query(
               ~s([aria-label="#{chain} chain"] img[src="/images/chains/#{filename}"])
             )
             |> Enum.any?()
    end
  end

  test "keeps the network SVG files in priv/static" do
    for filename <- Map.values(@chain_icons) do
      assert File.regular?(
               Path.expand("../../../../priv/static/images/chains/#{filename}", __DIR__)
             )
    end
  end
end
