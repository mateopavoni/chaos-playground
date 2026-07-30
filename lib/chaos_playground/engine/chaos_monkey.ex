defmodule ChaosPlayground.Engine.ChaosMonkey do
  @moduledoc """
  Cuando está prendido, mata un nodo vivo al azar de la topología actual cada
  @tick_ms — chaos engineering en piloto automático, mismo botón de "matar
  proceso" que ya usa el Inspector, solo que lo aprieta un timer en vez de un click.
  """

  use GenServer

  alias ChaosPlayground.Engine.{NodeServer, NodeSupervisor, TrafficSimulator}

  @tick_ms 6_000

  defstruct enabled?: false

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  @spec toggle() :: boolean()
  def toggle, do: GenServer.call(__MODULE__, :toggle)

  @spec enabled?() :: boolean()
  def enabled?, do: GenServer.call(__MODULE__, :enabled?)

  @impl true
  def init(:ok) do
    schedule_tick()
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_call(:toggle, _from, state) do
    new_state = %{state | enabled?: not state.enabled?}
    {:reply, new_state.enabled?, new_state}
  end

  def handle_call(:enabled?, _from, state), do: {:reply, state.enabled?, state}

  @impl true
  def handle_info(:tick, state) do
    if state.enabled?, do: kill_random_node()
    schedule_tick()
    {:noreply, state}
  end

  defp kill_random_node do
    case TrafficSimulator.get_state().topology do
      nil -> :ok
      topology -> topology.nodes |> Enum.map(& &1.id) |> alive_ids() |> pick_and_kill()
    end
  end

  defp alive_ids(ids) do
    Enum.filter(ids, fn id ->
      case NodeServer.get_state(id) do
        {:error, :not_found} -> false
        %NodeServer{status: status} -> status != :dead
      end
    end)
  end

  defp pick_and_kill([]), do: :ok
  defp pick_and_kill(ids), do: NodeSupervisor.kill_node(Enum.random(ids))

  defp schedule_tick, do: Process.send_after(self(), :tick, @tick_ms)
end
