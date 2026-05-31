defmodule AssetMonitoringDashWeb.AssetLive.AssetEventFilters do
  @moduledoc """
  Assign and display helpers for asset detail activity filters.
  """

  import Phoenix.Component, only: [assign: 3, to_form: 2]

  alias AssetMonitoringDashWeb.AssetDetailURLState

  def assign_state(socket, filters) do
    socket
    |> assign(:asset_event_filters, filters)
    |> assign(:asset_event_filter_form, form(filters))
    |> assign(:active_asset_event_filter_chips, active_chips(filters))
  end

  def options do
    [
      %{value: "scenario", label: "Scenario", icon_text: "Sc", tone: :warning},
      %{value: "operator", label: "Operator", icon_text: "O", tone: :success}
    ]
  end

  def normalize(params) do
    %{
      sources: Map.get(params, "sources") || Map.get(params, :sources),
      source_option_query:
        Map.get(params, "source_option_query") || Map.get(params, :source_option_query)
    }
    |> AssetDetailURLState.new()
    |> Map.fetch!(:event_filters)
  end

  def filter_events(events, []), do: events

  def filter_events(events, sources) do
    Enum.filter(events, &(Map.get(&1, :source_value, source_value(&1)) in sources))
  end

  def form(filters) do
    to_form(
      %{
        "sources" => filters.sources,
        "source_option_query" => filters.source_option_query
      },
      as: :asset_event_filters
    )
  end

  def active_chips(filters) do
    options()
    |> Map.new(&{&1.value, &1})
    |> then(fn options_by_value ->
      Enum.map(filters.sources, fn value ->
        option = options_by_value[value]

        option
        |> Map.take([:icon_text, :label, :tone])
        |> Map.merge(%{
          id: "asset-event-sources-#{chip_id(value)}",
          field: "asset_event_sources",
          value: value,
          group: "Source"
        })
      end)
    end)
  end

  defp source_value(%{kind: kind}) when is_atom(kind), do: Atom.to_string(kind)
  defp source_value(_event), do: "system"

  defp chip_id(value) do
    value
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9_-]/, "-")
  end
end
