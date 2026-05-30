defmodule AssetMonitoringDashWeb.UI.AssetIconTest do
  use AssetMonitoringDashWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias AssetMonitoringDashWeb.UI.AssetIcon

  @asset_icons ~w(
    battle-pass
    dragon-helm
    drift-chassis
    ember-crown
    founder-parcel
    guild-charter
    mana-vault
    mech-core
    pulse-racer
    victory-crate
    void-skin
    warbeast
  )

  test "renders local SVG files for every supported asset icon" do
    for icon <- @asset_icons do
      document =
        render_component(&AssetIcon.render/1, icon: icon, fallback: "AX")
        |> LazyHTML.from_fragment()

      assert document
             |> LazyHTML.query(~s(img[src="/images/assets/#{icon}.svg"]))
             |> Enum.any?()
    end
  end

  test "keeps the asset SVG files in priv/static" do
    for icon <- @asset_icons do
      assert File.regular?(
               Path.expand("../../../../priv/static/images/assets/#{icon}.svg", __DIR__)
             )
    end
  end

  test "falls back to initials for unknown icon keys" do
    html = render_component(&AssetIcon.render/1, icon: "unknown", fallback: "AX")

    assert html =~ "AX"
    refute html =~ "/images/assets/unknown.svg"
  end
end
