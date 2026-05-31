defmodule AssetMonitoringDashWeb.AssetLiveTestHelpers do
  @moduledoc false

  import Phoenix.LiveViewTest, only: [element: 2, render_submit: 2]

  alias AssetMonitoringDash.Assets

  def submit_review_action(view, action, opts \\ []) do
    action = Atom.to_string(action)
    reason = Keyword.get(opts, :reason, "signal_reviewed")
    note = Keyword.get(opts, :note, "")

    view
    |> element("#review-action-form")
    |> render_submit(%{
      "review_action" => %{
        "action" => action,
        "reason" => reason,
        "note" => note
      }
    })
  end

  def patch_query_params(path) do
    path
    |> URI.parse()
    |> Map.fetch!(:query)
    |> case do
      nil -> %{}
      query -> URI.decode_query(query)
    end
  end

  def asset_path(code), do: "/assets/#{Assets.persisted_asset_id(code)}"
  def asset_path(code, query), do: "#{asset_path(code)}?#{query}"
end
