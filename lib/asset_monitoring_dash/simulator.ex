defmodule AssetMonitoringDash.Simulator do
  @moduledoc """
  Supervised process that drives the demo activity stream.

  The simulator owns the automatic tick cadence. Each tick records one persisted
  demo event through the activity boundary, then broadcasts the updated feed so
  LiveViews can react without running their own timers.
  """

  use GenServer

  alias AssetMonitoringDash.ActivityLog
  alias AssetMonitoringDash.Assets
  alias AssetMonitoringDash.AssetScenarioStore

  @default_interval_ms 4_000
  @default_max_active_scenarios 5
  @default_scenario_every 4
  @topic "simulator:activity"

  defstruct interval_ms: @default_interval_ms,
            max_active_scenarios: @default_max_active_scenarios,
            next_event_index: 0,
            paused?: false,
            pubsub_server: AssetMonitoringDash.PubSub,
            scenario_every: @default_scenario_every,
            timer_ref: nil,
            tick_index: 0,
            topic: @topic

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  def start_link(opts \\ []) do
    opts = Keyword.merge(config(), opts)

    case Keyword.get(opts, :enabled, true) do
      true -> GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
      false -> :ignore
    end
  end

  def subscribe do
    Phoenix.PubSub.subscribe(AssetMonitoringDash.PubSub, @topic)
  end

  def tick(server \\ __MODULE__) do
    call(server, :tick)
  end

  def pause(server \\ __MODULE__) do
    call(server, :pause)
  end

  def resume(server \\ __MODULE__) do
    call(server, :resume)
  end

  def status(server \\ __MODULE__) do
    call(server, :status)
  end

  @impl true
  def init(opts) do
    state = %__MODULE__{
      interval_ms: Keyword.get(opts, :interval_ms, @default_interval_ms),
      max_active_scenarios:
        Keyword.get(opts, :max_active_scenarios, @default_max_active_scenarios),
      next_event_index:
        Keyword.get_lazy(opts, :next_event_index, &ActivityLog.next_demo_event_index/0),
      paused?: Keyword.get(opts, :paused?, false),
      pubsub_server: Keyword.get(opts, :pubsub_server, AssetMonitoringDash.PubSub),
      scenario_every: Keyword.get(opts, :scenario_every, @default_scenario_every),
      tick_index: Keyword.get(opts, :tick_index, 0),
      topic: Keyword.get(opts, :topic, @topic)
    }

    {:ok, schedule_tick(state)}
  end

  @impl true
  def handle_call(:tick, _from, state) do
    {feed, state} = record_activity_tick(state)

    {:reply, feed, state}
  end

  def handle_call(:pause, _from, state) do
    state =
      state
      |> cancel_timer()
      |> Map.put(:paused?, true)

    {:reply, status_payload(state), state}
  end

  def handle_call(:resume, _from, %{paused?: true} = state) do
    state =
      state
      |> Map.put(:paused?, false)
      |> schedule_tick()

    {:reply, status_payload(state), state}
  end

  def handle_call(:resume, _from, state) do
    {:reply, status_payload(state), state}
  end

  def handle_call(:status, _from, state) do
    {:reply, status_payload(state), state}
  end

  @impl true
  def handle_info(:tick, %{paused?: true} = state) do
    {:noreply, %{state | timer_ref: nil}}
  end

  def handle_info(:tick, state) do
    {_payload, state} = record_scheduled_tick(state)

    {:noreply, schedule_tick(state)}
  end

  defp record_scheduled_tick(state) do
    case scenario_tick?(state) do
      true -> record_scenario_tick(state)
      false -> record_activity_tick(state)
    end
  end

  defp record_activity_tick(state) do
    feed = ActivityLog.record_demo_event(state.next_event_index)

    Phoenix.PubSub.broadcast(
      state.pubsub_server,
      state.topic,
      {__MODULE__, :event_recorded, feed}
    )

    {feed, %{state | next_event_index: feed.next_event_index, tick_index: state.tick_index + 1}}
  end

  defp record_scenario_tick(state) do
    case next_scenario_asset(state) do
      nil ->
        record_activity_tick(state)

      asset ->
        shocked_asset_ids = AssetScenarioStore.apply_price_shock(asset.id)
        asset = Assets.get_persisted_asset_with_scenarios(asset.id, shocked_asset_ids)

        event_history =
          ActivityLog.record_price_shock(asset, AssetScenarioStore.price_shock_drop_percent())

        payload = %{
          asset: asset,
          event_history: event_history,
          next_event_index: state.next_event_index,
          shocked_asset_ids: shocked_asset_ids
        }

        Phoenix.PubSub.broadcast(
          state.pubsub_server,
          state.topic,
          {__MODULE__, :scenario_applied, payload}
        )

        {payload, %{state | tick_index: state.tick_index + 1}}
    end
  end

  defp call(server, message) do
    case server_pid(server) do
      nil -> {:error, :not_started}
      pid -> GenServer.call(pid, message)
    end
  end

  defp server_pid(pid) when is_pid(pid), do: pid
  defp server_pid(name) when is_atom(name), do: Process.whereis(name)

  defp scenario_tick?(%{scenario_every: scenario_every} = state)
       when is_integer(scenario_every) and scenario_every > 0 do
    rem(state.tick_index + 1, scenario_every) == 0
  end

  defp scenario_tick?(_state), do: false

  defp next_scenario_asset(state) do
    shocked_asset_ids = AssetScenarioStore.shocked_asset_ids()

    case MapSet.size(shocked_asset_ids) >= state.max_active_scenarios do
      true ->
        nil

      false ->
        state
        |> scenario_candidates(shocked_asset_ids)
        |> select_scenario_candidate(state.tick_index)
    end
  end

  defp scenario_candidates(_state, shocked_asset_ids) do
    Assets.list_persisted_assets()
    |> Enum.reject(&Assets.asset_id_in_set?(&1.id, shocked_asset_ids))
    |> Enum.filter(&scenario_candidate?/1)
  end

  defp scenario_candidate?(%{risk_band: risk_band}), do: risk_band in ["Moderate", "Elevated"]

  defp select_scenario_candidate([], _tick_index), do: nil

  defp select_scenario_candidate(candidates, tick_index) do
    Enum.at(candidates, rem(tick_index, length(candidates)))
  end

  defp schedule_tick(%{paused?: true} = state), do: state

  defp schedule_tick(%{interval_ms: interval_ms} = state) when is_integer(interval_ms) do
    %{state | timer_ref: Process.send_after(self(), :tick, interval_ms)}
  end

  defp schedule_tick(state), do: state

  defp cancel_timer(%{timer_ref: nil} = state), do: state

  defp cancel_timer(%{timer_ref: timer_ref} = state) do
    case Process.cancel_timer(timer_ref) do
      false -> flush_pending_tick()
      _remaining_time -> :ok
    end

    %{state | timer_ref: nil}
  end

  defp flush_pending_tick do
    receive do
      :tick -> :ok
    after
      0 -> :ok
    end
  end

  defp status_payload(state) do
    %{
      interval_ms: state.interval_ms,
      max_active_scenarios: state.max_active_scenarios,
      next_event_index: state.next_event_index,
      paused?: state.paused?,
      scenario_every: state.scenario_every,
      tick_index: state.tick_index
    }
  end

  defp config do
    Application.get_env(:asset_monitoring_dash, __MODULE__, [])
  end
end
