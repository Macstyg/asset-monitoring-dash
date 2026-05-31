defmodule AssetMonitoringDashWeb.AssetDetailURLState do
  @moduledoc """
  URL-backed state for the asset detail inspection page.
  """

  @source_options ["scenario", "operator"]
  @focus_options ["overview", "activity", "related"]
  @default_focus "overview"

  @type event_filters :: %{
          required(:sources) => [String.t()],
          required(:source_option_query) => String.t()
        }
  @type t :: %__MODULE__{event_filters: event_filters(), focus: String.t()}

  @enforce_keys [:event_filters, :focus]
  defstruct [:event_filters, :focus]

  @spec default() :: t()
  def default do
    new(default_event_filters())
  end

  @spec from_params(map()) :: t()
  def from_params(params) do
    new(%{
      sources: normalize_sources(Map.get(params, "activity_sources")),
      source_option_query: "",
      focus: Map.get(params, "focus")
    })
  end

  @spec new(map()) :: t()
  def new(attrs) do
    %__MODULE__{
      event_filters: %{
        sources: normalize_sources(Map.get(attrs, :sources)),
        source_option_query: normalize_query(Map.get(attrs, :source_option_query))
      },
      focus: normalize_focus(Map.get(attrs, :focus))
    }
  end

  @spec with_event_filters(t(), event_filters()) :: t()
  def with_event_filters(%__MODULE__{} = state, event_filters) do
    %{state | event_filters: new(event_filters).event_filters}
  end

  @spec with_focus(t(), String.t()) :: t()
  def with_focus(%__MODULE__{} = state, focus) do
    %{state | focus: normalize_focus(focus)}
  end

  @spec params(t()) :: map()
  def params(%__MODULE__{event_filters: event_filters, focus: focus}) do
    %{}
    |> put_sources_param(event_filters.sources)
    |> put_focus_param(focus)
  end

  @spec same_url_params?(t(), t()) :: boolean()
  def same_url_params?(%__MODULE__{} = left, %__MODULE__{} = right) do
    params(left) == params(right)
  end

  defp default_event_filters do
    %{sources: [], source_option_query: "", focus: @default_focus}
  end

  defp normalize_sources(nil), do: []

  defp normalize_sources(values) do
    values
    |> List.wrap()
    |> Enum.flat_map(&split_source_value/1)
    |> Enum.map(&String.trim/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.filter(&(&1 in @source_options))
    |> Enum.uniq()
  end

  defp split_source_value(value) when is_binary(value), do: String.split(value, ",")
  defp split_source_value(value), do: [to_string(value)]

  defp normalize_query(nil), do: ""

  defp normalize_query(query) do
    query
    |> String.trim()
    |> String.downcase()
  end

  defp normalize_focus(focus) when focus in @focus_options, do: focus
  defp normalize_focus(_focus), do: @default_focus

  defp put_sources_param(params, []), do: params

  defp put_sources_param(params, sources) do
    Map.put(params, "activity_sources", Enum.join(sources, ","))
  end

  defp put_focus_param(params, @default_focus), do: params
  defp put_focus_param(params, focus), do: Map.put(params, "focus", focus)
end
