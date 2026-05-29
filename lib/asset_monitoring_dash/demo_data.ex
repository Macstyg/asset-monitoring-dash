defmodule AssetMonitoringDash.DemoData do
  @moduledoc """
  Deterministic demo data for the first dashboard slices.

  The values here are deliberately small and explicit while the product shape is
  still forming. Later milestones can replace these functions with Ecto-backed
  contexts without forcing the LiveView to know where the data came from.
  """

  def portfolio_snapshot do
    %{
      total_collateral_value_usd: 12_840_000,
      collateral_delta_percent: 4.8,
      active_loans: 132,
      active_loans_delta: 9,
      weighted_apy_percent: 13.7,
      apy_delta_percent: -0.4,
      risk_score: 68,
      risk_delta: 6,
      risk_band: "Elevated"
    }
  end

  def live_events do
    [
      %{
        id: "event-001",
        time_label: "14:28:09",
        title: "Collateral deposited",
        detail: "Aegis Dragon Helm moved into Polygon escrow for loan review.",
        chain: "Polygon",
        status: "synced",
        tone: :success
      },
      %{
        id: "event-002",
        time_label: "14:27:31",
        title: "Floor oracle moved",
        detail: "Embervale parcel floor repriced down 3.2% after auction close.",
        chain: "Ethereum",
        status: "watch",
        tone: :warning
      },
      %{
        id: "event-003",
        time_label: "14:26:44",
        title: "Repayment received",
        detail: "Rift Racers position closed early; collateral release is queued.",
        chain: "Base",
        status: "settled",
        tone: :success
      },
      %{
        id: "event-004",
        time_label: "14:25:18",
        title: "Health factor breach",
        detail: "Ancient Mech Core crossed the critical review threshold.",
        chain: "Arbitrum",
        status: "risk",
        tone: :danger
      },
      %{
        id: "event-005",
        time_label: "14:23:52",
        title: "Cross-chain transfer",
        detail: "Stormforged Battle Pass bridged into Ronin collateral custody.",
        chain: "Ronin",
        status: "pending",
        tone: :neutral
      }
    ]
  end

  def next_live_event(index) when is_integer(index) and index >= 0 do
    templates = live_event_templates()
    template = Enum.at(templates, rem(index, length(templates)))

    template
    |> Map.put(:id, "event-live-#{index + 1}")
    |> Map.put(:time_label, "now")
  end

  def monitored_assets do
    [
      %{
        id: "asset-001",
        name: "Aegis Dragon Helm",
        asset_type: "NFT",
        chain: "Polygon",
        ecosystem: "Skyforge Arena",
        rarity: "Legendary",
        floor_price_usd: 4_200,
        current_value_usd: 4_860,
        loan_value_usd: 2_900,
        ltv_percent: 59.7,
        risk_score: 64,
        risk_band: "Elevated",
        oracle_freshness_seconds: 24,
        market_depth_usd: 42_000
      },
      %{
        id: "asset-002",
        name: "Citadel Founder Parcel",
        asset_type: "NFT",
        chain: "Ethereum",
        ecosystem: "Embervale",
        rarity: "Mythic",
        floor_price_usd: 18_400,
        current_value_usd: 21_150,
        loan_value_usd: 15_900,
        ltv_percent: 75.2,
        risk_score: 88,
        risk_band: "Critical",
        oracle_freshness_seconds: 32,
        market_depth_usd: 110_000
      },
      %{
        id: "asset-003",
        name: "Neon Pulse Racer",
        asset_type: "NFT",
        chain: "Base",
        ecosystem: "Rift Racers",
        rarity: "Epic",
        floor_price_usd: 2_750,
        current_value_usd: 3_120,
        loan_value_usd: 1_180,
        ltv_percent: 37.8,
        risk_score: 29,
        risk_band: "Low",
        oracle_freshness_seconds: 18,
        market_depth_usd: 18_500
      },
      %{
        id: "asset-004",
        name: "Ronin Warbeast",
        asset_type: "NFT",
        chain: "Ronin",
        ecosystem: "Skyforge Arena",
        rarity: "Rare",
        floor_price_usd: 1_280,
        current_value_usd: 1_510,
        loan_value_usd: 760,
        ltv_percent: 50.3,
        risk_score: 46,
        risk_band: "Moderate",
        oracle_freshness_seconds: 620,
        market_depth_usd: 4_200
      },
      %{
        id: "asset-005",
        name: "Genesis Mana Vault",
        asset_type: "ERC-1155",
        chain: "Arbitrum",
        ecosystem: "Neon Dominion",
        rarity: "Legendary",
        floor_price_usd: 7_900,
        current_value_usd: 8_240,
        loan_value_usd: 5_620,
        ltv_percent: 68.2,
        risk_score: 71,
        risk_band: "Elevated",
        oracle_freshness_seconds: 184,
        market_depth_usd: 12_800
      },
      %{
        id: "asset-006",
        name: "Void Atlas Skin",
        asset_type: "NFT",
        chain: "Immutable",
        ecosystem: "Neon Dominion",
        rarity: "Epic",
        floor_price_usd: 940,
        current_value_usd: 1_060,
        loan_value_usd: 410,
        ltv_percent: 38.7,
        risk_score: 34,
        risk_band: "Low",
        oracle_freshness_seconds: 760,
        market_depth_usd: 2_200
      },
      %{
        id: "asset-007",
        name: "Ember Crown Relic",
        asset_type: "NFT",
        chain: "Ethereum",
        ecosystem: "Embervale",
        rarity: "Legendary",
        floor_price_usd: 12_600,
        current_value_usd: 13_950,
        loan_value_usd: 8_740,
        ltv_percent: 62.7,
        risk_score: 66,
        risk_band: "Elevated",
        oracle_freshness_seconds: 41,
        market_depth_usd: 58_000
      },
      %{
        id: "asset-008",
        name: "Turbo Drift Chassis",
        asset_type: "NFT",
        chain: "Base",
        ecosystem: "Rift Racers",
        rarity: "Rare",
        floor_price_usd: 1_720,
        current_value_usd: 1_890,
        loan_value_usd: 980,
        ltv_percent: 51.9,
        risk_score: 49,
        risk_band: "Moderate",
        oracle_freshness_seconds: 216,
        market_depth_usd: 6_400
      },
      %{
        id: "asset-009",
        name: "Moonwell Guild Charter",
        asset_type: "ERC-1155",
        chain: "Polygon",
        ecosystem: "Moonwell Tactics",
        rarity: "Epic",
        floor_price_usd: 3_450,
        current_value_usd: 3_780,
        loan_value_usd: 2_260,
        ltv_percent: 59.8,
        risk_score: 58,
        risk_band: "Moderate",
        oracle_freshness_seconds: 58,
        market_depth_usd: 2_750
      },
      %{
        id: "asset-010",
        name: "Ancient Mech Core",
        asset_type: "NFT",
        chain: "Arbitrum",
        ecosystem: "Mecha Rift",
        rarity: "Mythic",
        floor_price_usd: 9_300,
        current_value_usd: 8_760,
        loan_value_usd: 7_020,
        ltv_percent: 80.1,
        risk_score: 92,
        risk_band: "Critical",
        oracle_freshness_seconds: 725,
        market_depth_usd: 5_900
      },
      %{
        id: "asset-011",
        name: "Sealed Victory Crate",
        asset_type: "ERC-1155",
        chain: "Immutable",
        ecosystem: "Moonwell Tactics",
        rarity: "Uncommon",
        floor_price_usd: 420,
        current_value_usd: 455,
        loan_value_usd: 120,
        ltv_percent: 26.4,
        risk_score: 18,
        risk_band: "Low",
        oracle_freshness_seconds: 36,
        market_depth_usd: 1_100
      },
      %{
        id: "asset-012",
        name: "Stormforged Battle Pass",
        asset_type: "Tokenized pass",
        chain: "Ronin",
        ecosystem: "Skyforge Arena",
        rarity: "Rare",
        floor_price_usd: 680,
        current_value_usd: 710,
        loan_value_usd: 360,
        ltv_percent: 50.7,
        risk_score: 44,
        risk_band: "Moderate",
        oracle_freshness_seconds: 58,
        market_depth_usd: 3_900
      }
    ]
  end

  defp live_event_templates do
    [
      %{
        title: "Oracle heartbeat",
        detail: "Polygon and Base floor feeds confirmed within the freshness window.",
        chain: "Multi-chain",
        status: "live",
        tone: :success
      },
      %{
        title: "Collateral value drop",
        detail: "Ancient Mech Core marked 4.8% lower after a thin marketplace sale.",
        chain: "Arbitrum",
        status: "watch",
        tone: :warning
      },
      %{
        title: "Liquidation review",
        detail: "Citadel Founder Parcel entered manual review at 75.2% LTV.",
        chain: "Ethereum",
        status: "risk",
        tone: :danger
      },
      %{
        title: "Borrower top-up",
        detail: "Skyforge borrower added Ronin Warbeast collateral to improve health.",
        chain: "Ronin",
        status: "synced",
        tone: :success
      }
    ]
  end
end
