defmodule AssetMonitoringDashWeb.AssetLive.ViewModel do
  @moduledoc """
  Derived assign model for the asset detail page.

  The LiveView owns routing, events, and streaming. This module owns the
  product-specific projection from an asset plus mutable review/scenario state
  into the assigns consumed by the detail components.
  """

  alias AssetMonitoringDash.Assets
  alias AssetMonitoringDash.AssetScenarioStore
  alias AssetMonitoringDash.ReviewState
  alias AssetMonitoringDash.ReviewStore
  alias AssetMonitoringDash.Risk
  alias AssetMonitoringDash.RiskRecommendation
  alias AssetMonitoringDashWeb.AssetLive.RelatedAssetRanker
  alias AssetMonitoringDashWeb.Formatters

  @related_asset_limit 4
  @related_asset_candidate_limit 24

  defstruct [
    :active_scenario,
    :asset,
    :asset_escalated?,
    :asset_health_factor,
    :asset_ltv_trend,
    :asset_review_state,
    :asset_reviewed?,
    :asset_risk_explanation,
    :asset_risk_recommendation,
    :asset_shocked?,
    :page_title,
    :related_assets,
    :review_history
  ]

  def build(asset, opts) do
    review_states = Keyword.fetch!(opts, :review_states)
    shocked_asset_ids = Keyword.fetch!(opts, :shocked_asset_ids)
    review_state = ReviewState.state_for(asset.id, review_states)
    risk_recommendation = RiskRecommendation.recommendation_for(asset)

    related_candidates =
      Assets.list_related_asset_candidates(asset, shocked_asset_ids,
        limit: Keyword.get(opts, :related_asset_candidate_limit, @related_asset_candidate_limit)
      )

    %__MODULE__{
      active_scenario: AssetScenarioStore.scenario_option_for_asset(asset.id),
      asset: asset,
      asset_escalated?: review_state.id == :escalated,
      asset_health_factor: asset |> Risk.health_factor() |> Formatters.decimal(),
      asset_ltv_trend: Assets.ltv_trend(asset),
      asset_review_state: review_state,
      asset_reviewed?: review_state.id == :reviewed,
      asset_risk_explanation: Risk.explanation(asset),
      asset_risk_recommendation: risk_recommendation,
      asset_shocked?: Assets.asset_id_in_set?(asset.id, shocked_asset_ids),
      page_title: "#{asset.name} · Asset detail",
      related_assets:
        RelatedAssetRanker.related_assets(asset, related_candidates,
          limit: Keyword.get(opts, :related_asset_limit, @related_asset_limit)
        ),
      review_history: ReviewStore.history_for(asset.id)
    }
  end

  def assigns(%__MODULE__{} = view_model), do: Map.from_struct(view_model)
end
