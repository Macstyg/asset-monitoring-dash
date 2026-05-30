defmodule AssetMonitoringDashWeb.FormattersTest do
  use ExUnit.Case, async: true

  alias AssetMonitoringDashWeb.Formatters

  describe "currency formatting" do
    test "formats compact USD values in millions" do
      assert Formatters.compact_usd(12_800_000) == "$12.8M"
    end

    test "formats compact USD values in thousands" do
      assert Formatters.compact_usd(69_485) == "$69.5K"
    end

    test "formats USD values with thousands separators" do
      assert Formatters.usd(18_400) == "$18,400"
    end
  end

  describe "percentage formatting" do
    test "formats LTV values" do
      assert Formatters.ltv(59.7) == "59.7%"
    end

    test "formats signed percentages" do
      assert Formatters.signed_percent(4.8) == "+4.8%"
      assert Formatters.signed_percent(-0.4) == "-0.4%"
    end
  end
end
