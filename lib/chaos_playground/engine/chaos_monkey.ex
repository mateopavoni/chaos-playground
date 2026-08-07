defmodule ChaosPlayground.Engine.ChaosMonkey do
  @moduledoc """
  Cuando está prendido, mata un nodo vivo al azar de la topología actual cada
  @tick_ms — chaos engineering en piloto automático, mismo botón de "matar
  proceso" que ya usa el Inspector, solo que lo aprieta un timer en vez de un click.
  """

  use GenServer

  alias ChaosPlayground.Engine.{EngineRegistry, NodeServer, NodeSupervisor, TrafficSimulator}

  @tick_ms 6_000

  defstruct user_id: nil, enabled?: false

  def start_link(user_id), do: GenServer.start_link(__MODULE__, user_id, name: via(user_id))

  defp via(user_id), do: EngineRegistry.via_tuple(:chaos_monkey, user_id)

  @spec toggle(term()) :: boolean()
  def toggle(user_id), do: GenServer.call(via(user_id), :toggle)

  @spec enabled?(term()) :: boolean()
  def enabled?(user_id), do: GenServer.call(via(user_id), :enabled?)

  @impl true
  def init(user_id) do
    schedule_tick()
    {:ok, %__MODULE__{user_id: user_id}}
  end

  @impl true
  def handle_call(:toggle, _from, state) do
    new_state = %{state | enabled?: not state.enabled?}
    {:reply, new_state.enabled?, new_state}
  end

  def handle_call(:enabled?, _from, state), do: {:reply, state.enabled?, state}

  @impl true
  def handle_info(:tick, state) do
    if state.enabled?, do: kill_random_node(state.user_id)
    schedule_tick()
    {:noreply, state}
  end

  defp kill_random_node(user_id) do
    case TrafficSimulator.get_state(user_id).topology do
      nil ->
        :ok

      topology ->
        topology.nodes |> Enum.map(& &1.id) |> alive_ids(user_id) |> pick_and_kill(user_id)
    end
  end

  defp alive_ids(ids, user_id) do
    Enum.filter(ids, fn id ->
      case NodeServer.get_state(user_id, id) do
        {:error, :not_found} -> false
        %NodeServer{status: status} -> status != :dead
      end
    end)
  end

  defp pick_and_kill([], _user_id), do: :ok
  defp pick_and_kill(ids, user_id), do: NodeSupervisor.kill_node(user_id, Enum.random(ids))

  defp schedule_tick, do: Process.send_after(self(), :tick, @tick_ms)
end
