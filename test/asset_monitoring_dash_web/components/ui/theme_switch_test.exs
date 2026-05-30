defmodule AssetMonitoringDashWeb.UI.ThemeSwitchTest do
  use AssetMonitoringDashWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias AssetMonitoringDashWeb.UI.ThemeSwitch

  test "renders paired theme actions backed by the root theme handler" do
    document =
      render_component(&ThemeSwitch.render/1)
      |> LazyHTML.from_fragment()

    assert document
           |> LazyHTML.query(~s(#theme-toggle-dark[phx-click][data-phx-theme="dark"]))
           |> Enum.any?()

    assert document
           |> LazyHTML.query(~s(#theme-toggle-light[phx-click][data-phx-theme="light"]))
           |> Enum.any?()

    assert document
           |> LazyHTML.query(~s(#theme-toggle-dark[aria-label="Switch to dark theme"]))
           |> Enum.any?()

    assert document
           |> LazyHTML.query(~s(#theme-toggle-light[aria-label="Switch to light theme"]))
           |> Enum.any?()
  end

  test "allows the root id to be customized while keeping child ids stable to it" do
    document =
      render_component(&ThemeSwitch.render/1, id: "app-theme")
      |> LazyHTML.from_fragment()

    assert document
           |> LazyHTML.query("#app-theme")
           |> Enum.any?()

    assert document
           |> LazyHTML.query(~s(#app-theme-dark[data-phx-theme="dark"]))
           |> Enum.any?()

    assert document
           |> LazyHTML.query(~s(#app-theme-light[data-phx-theme="light"]))
           |> Enum.any?()
  end
end
