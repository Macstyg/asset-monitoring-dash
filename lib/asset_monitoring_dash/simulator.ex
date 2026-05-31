defmodule AssetMonitoringDash.Simulator do
  @moduledoc """
  Supervised process that drives the demo activity stream.

  The simulator owns the automatic tick cadence. Each tick records one persisted
  demo event through the activity boundary, then broadcasts the updated feed so
  LiveViews can react without running their own timers.
  """

  use GenServer

  alias AssetMonitoringDash.ActivityLog

  @default_interval_ms 4_000
  @topic "simulator:activity"

  defstruct interval_ms: @default_interval_ms,
            next_event_index: 0,
            paused?: false,
            pubsub_server: AssetMonitoringDash.PubSub,
            timer_ref: nil,
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
      next_event_index:
        Keyword.get_lazy(opts, :next_event_index, &ActivityLog.next_demo_event_index/0),
      paused?: Keyword.get(opts, :paused?, false),
      pubsub_server: Keyword.get(opts, :pubsub_server, AssetMonitoringDash.PubSub),
      topic: Keyword.get(opts, :topic, @topic)
    }

    {:ok, schedule_tick(state)}
  end

  @impl true
  def handle_call(:tick, _from, state) do
    {feed, state} = record_tick(state)

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
    {_feed, state} = record_tick(state)

    {:noreply, schedule_tick(state)}
  end

  defp record_tick(state) do
    feed = ActivityLog.record_demo_event(state.next_event_index)

    Phoenix.PubSub.broadcast(
      state.pubsub_server,
      state.topic,
      {__MODULE__, :event_recorded, feed}
    )

    {feed, %{state | next_event_index: feed.next_event_index, timer_ref: nil}}
  end

  defp call(server, message) do
    case server_pid(server) do
      nil -> {:error, :not_started}
      pid -> GenServer.call(pid, message)
    end
  end

  defp server_pid(pid) when is_pid(pid), do: pid
  defp server_pid(name) when is_atom(name), do: Process.whereis(name)

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
      next_event_index: state.next_event_index,
      paused?: state.paused?
    }
  end

  defp config do
    Application.get_env(:asset_monitoring_dash, __MODULE__, [])
  end
end
