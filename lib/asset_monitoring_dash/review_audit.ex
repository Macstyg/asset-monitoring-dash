defmodule AssetMonitoringDash.ReviewAudit do
  @moduledoc """
  Operator-supplied audit context for review workflow actions.
  """

  @enforce_keys [:reason, :note]
  defstruct [:reason, :note]

  def new(attrs \\ %{}) do
    normalize(attrs)
  end

  def normalize(%__MODULE__{} = audit) do
    %__MODULE__{
      reason: normalize_value(audit.reason),
      note: normalize_value(audit.note)
    }
  end

  def normalize(attrs) when is_map(attrs) do
    %__MODULE__{
      reason: normalize_value(Map.get(attrs, :reason) || Map.get(attrs, "reason")),
      note: normalize_value(Map.get(attrs, :note) || Map.get(attrs, "note"))
    }
  end

  def normalize(_attrs), do: empty()

  def empty, do: %__MODULE__{reason: "", note: ""}

  defp normalize_value(nil), do: ""

  defp normalize_value(value) do
    value
    |> to_string()
    |> String.trim()
  end
end
