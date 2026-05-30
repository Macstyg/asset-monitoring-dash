defmodule AssetMonitoringDashWeb.DashboardURLState do
  @moduledoc """
  URL-backed state for the dashboard asset monitor.

  This module owns the boundary between query-string params and the explicit
  filter/sort shape the LiveView uses internally.
  """

  alias AssetMonitoringDash.Assets

  @default_sort %{field: :ltv, direction: :desc}
  @filter_param_keys ["query", "risks", "chains", "actions", "operator_states"]

  @type sort_field :: :asset | :chain | :floor | :value | :ltv | :risk | :operator | :action
  @type sort_direction :: :asc | :desc
  @type sort :: %{required(:field) => sort_field(), required(:direction) => sort_direction()}
  @type filters :: %{
          required(:query) => String.t(),
          required(:risks) => [String.t()],
          required(:chains) => [String.t()],
          required(:actions) => [String.t()],
          required(:operator_states) => [String.t()],
          required(:risk_option_query) => String.t(),
          required(:chain_option_query) => String.t(),
          required(:action_option_query) => String.t(),
          required(:operator_state_option_query) => String.t()
        }
  @type t :: %__MODULE__{filters: filters(), sort: sort()}

  @enforce_keys [:filters, :sort]
  defstruct [:filters, :sort]

  @spec default() :: t()
  def default do
    new(Assets.default_filters(), @default_sort)
  end

  @spec default_sort() :: sort()
  def default_sort, do: @default_sort

  @spec from_params(map()) :: t()
  def from_params(params) do
    filters =
      params
      |> Map.take(@filter_param_keys)
      |> Assets.normalize_filters(Assets.default_filters())

    new(filters, sort_from_params(params))
  end

  @spec new(filters(), sort()) :: t()
  def new(filters, sort) do
    %__MODULE__{filters: filters, sort: normalize_sort(sort)}
  end

  @spec with_filters(t(), filters()) :: t()
  def with_filters(%__MODULE__{} = state, filters), do: %{state | filters: filters}

  @spec with_sort(t(), sort()) :: t()
  def with_sort(%__MODULE__{} = state, sort), do: %{state | sort: normalize_sort(sort)}

  @spec next_sort(t(), String.t() | atom()) :: t()
  def next_sort(%__MODULE__{} = state, field) do
    field
    |> normalize_sort_field()
    |> next_sort_for_field(state.sort)
    |> then(&with_sort(state, &1))
  end

  @spec remove_filter_value(t(), atom(), String.t()) :: t()
  def remove_filter_value(%__MODULE__{filters: filters} = state, field, value) do
    filters =
      Map.update!(filters, field, fn values ->
        Enum.reject(values, &(&1 == value))
      end)

    with_filters(state, filters)
  end

  @spec params(t()) :: map()
  def params(%__MODULE__{} = state) do
    state
    |> filter_params()
    |> Map.merge(sort_params(state.sort))
  end

  @spec active?(t()) :: boolean()
  def active?(%__MODULE__{} = state), do: params(state) != %{}

  @spec filter_params(t()) :: map()
  def filter_params(%__MODULE__{filters: filters}) do
    %{}
    |> put_query_param("query", filters.query)
    |> put_list_query_param("risks", filters.risks)
    |> put_list_query_param("chains", filters.chains)
    |> put_list_query_param("actions", filters.actions)
    |> put_list_query_param("operator_states", filters.operator_states)
  end

  @spec same_filter_params?(t(), t()) :: boolean()
  def same_filter_params?(%__MODULE__{} = left, %__MODULE__{} = right) do
    filter_params(left) == filter_params(right)
  end

  defp sort_from_params(params) do
    field = normalize_sort_field(Map.get(params, "sort"))

    %{
      field: field,
      direction: normalize_sort_direction(Map.get(params, "dir"), field)
    }
  end

  defp normalize_sort(%{field: field, direction: direction}) do
    field = normalize_sort_field(field)

    %{
      field: field,
      direction: normalize_sort_direction(direction, field)
    }
  end

  defp normalize_sort(_sort), do: @default_sort

  defp normalize_sort_field("asset"), do: :asset
  defp normalize_sort_field("chain"), do: :chain
  defp normalize_sort_field("floor"), do: :floor
  defp normalize_sort_field("value"), do: :value
  defp normalize_sort_field("ltv"), do: :ltv
  defp normalize_sort_field("risk"), do: :risk
  defp normalize_sort_field("operator"), do: :operator
  defp normalize_sort_field("action"), do: :action
  defp normalize_sort_field(:asset), do: :asset
  defp normalize_sort_field(:chain), do: :chain
  defp normalize_sort_field(:floor), do: :floor
  defp normalize_sort_field(:value), do: :value
  defp normalize_sort_field(:ltv), do: :ltv
  defp normalize_sort_field(:risk), do: :risk
  defp normalize_sort_field(:operator), do: :operator
  defp normalize_sort_field(:action), do: :action
  defp normalize_sort_field(_field), do: @default_sort.field

  defp normalize_sort_direction("asc", _field), do: :asc
  defp normalize_sort_direction("desc", _field), do: :desc
  defp normalize_sort_direction(:asc, _field), do: :asc
  defp normalize_sort_direction(:desc, _field), do: :desc
  defp normalize_sort_direction(_direction, field), do: default_sort_direction(field)

  defp next_sort_for_field(field, %{field: field, direction: :desc}),
    do: %{field: field, direction: :asc}

  defp next_sort_for_field(field, %{field: field, direction: :asc}),
    do: %{field: field, direction: :desc}

  defp next_sort_for_field(field, _current_sort),
    do: %{field: field, direction: default_sort_direction(field)}

  defp default_sort_direction(:asset), do: :asc
  defp default_sort_direction(:chain), do: :asc
  defp default_sort_direction(_field), do: :desc

  defp sort_params(@default_sort), do: %{}

  defp sort_params(sort) do
    %{
      "sort" => Atom.to_string(sort.field),
      "dir" => Atom.to_string(sort.direction)
    }
  end

  defp put_query_param(params, _key, ""), do: params
  defp put_query_param(params, key, value), do: Map.put(params, key, value)

  defp put_list_query_param(params, _key, []), do: params

  defp put_list_query_param(params, key, values) do
    Map.put(params, key, Enum.join(values, ","))
  end
end
