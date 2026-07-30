defmodule ChaosPlayground.Engine.NodeServer do
  @moduledoc """
  Un nodo del canvas (load balancer, API server, DB, cache, queue...) respaldado por un proceso real.
  Estado: id, type, status (:healthy | :degraded | :dead), latency_ms, failure_rate, connections.
  """

  use GenServer

  alias ChaosPlayground.Engine.NodeRegistry

  defstruct [:id, :type, :status, :latency_ms, :failure_rate, :connections]

  @type status :: :healthy | :degraded | :dead
  @type t :: %__MODULE__{
          id: String.t(),
          type: atom(),
          status: status(),
          latency_ms: non_neg_integer(),
          failure_rate: float(),
          connections: [String.t()]
        }

  # Client API

  def start_link(attrs) do
    id = Keyword.fetch!(attrs, :id)
    GenServer.start_link(__MODULE__, attrs, name: NodeRegistry.via_tuple(id))
  end

  # ponytail: restart :temporary — un nodo "matado" queda muerto hasta que algo
  # vuelva a pedir start_node/1 con el mismo id (revivir es una acción explícita,
  # no magia del supervisor). Subir a :transient el día que haga falta auto-heal.
  def child_spec(attrs) do
    id = Keyword.fetch!(attrs, :id)

    %{
      id: {__MODULE__, id},
      start: {__MODULE__, :start_link, [attrs]},
      restart: :temporary
    }
  end

  @spec get_state(String.t()) :: t() | {:error, :not_found}
  def get_state(id), do: call(id, :get_state)

  # ponytail: Process.exit(pid, :kill) en NodeSupervisor.kill_node no dispara terminate/2,
  # asi que sin esto solo el browser que pidio el kill se enteraba (update optimista local) —
  # el resto de los visitantes del canvas compartido nunca veia el nodo caer.
  @spec mark_dead(String.t()) :: t() | {:error, :not_found}
  def mark_dead(id), do: call(id, :mark_dead)

  @spec handle_packet(String.t(), map()) :: {:ok, map()} | {:error, atom()}
  def handle_packet(id, packet), do: call(id, {:handle_packet, packet})

  def set_latency(id, ms) when is_integer(ms) and ms >= 0, do: cast(id, {:set_latency, ms})

  def set_failure_rate(id, rate) when is_float(rate) and rate >= 0.0 and rate <= 1.0,
    do: cast(id, {:set_failure_rate, rate})

  def connect(id, other_id), do: cast(id, {:connect, other_id})
  def disconnect(id, other_id), do: cast(id, {:disconnect, other_id})

  defp call(id, msg) do
    case NodeRegistry.whereis(id) do
      nil -> {:error, :not_found}
      pid -> GenServer.call(pid, msg)
    end
  end

  defp cast(id, msg) do
    case NodeRegistry.whereis(id) do
      nil -> {:error, :not_found}
      pid -> GenServer.cast(pid, msg)
    end
  end

  # Server callbacks

  @impl true
  def init(attrs) do
    state = %__MODULE__{
      id: Keyword.fetch!(attrs, :id),
      type: Keyword.fetch!(attrs, :type),
      status: :healthy,
      latency_ms: Keyword.get(attrs, :latency_ms, 0),
      failure_rate: Keyword.get(attrs, :failure_rate, 0.0),
      connections: Keyword.get(attrs, :connections, [])
    }

    broadcast(state)
    {:ok, state}
  end

  @impl true
  def handle_call(:get_state, _from, state), do: {:reply, state, state}

  def handle_call(:mark_dead, _from, state) do
    new_state = %{state | status: :dead}
    broadcast(new_state)
    {:reply, new_state, new_state}
  end

  def handle_call({:handle_packet, packet}, _from, state) do
    if state.latency_ms > 0, do: Process.sleep(state.latency_ms)

    if :rand.uniform() < state.failure_rate do
      new_state = %{state | status: :degraded}
      broadcast(new_state)
      {:reply, {:error, :node_failure}, new_state}
    else
      new_state = %{state | status: :healthy}
      broadcast(new_state)
      {:reply, {:ok, packet}, new_state}
    end
  end

  @impl true
  def handle_cast({:set_latency, ms}, state) do
    new_state = %{state | latency_ms: ms}
    broadcast(new_state)
    {:noreply, new_state}
  end

  def handle_cast({:set_failure_rate, rate}, state) do
    new_state = %{state | failure_rate: rate}
    broadcast(new_state)
    {:noreply, new_state}
  end

  def handle_cast({:connect, other_id}, state) do
    new_state = %{state | connections: Enum.uniq([other_id | state.connections])}
    broadcast(new_state)
    {:noreply, new_state}
  end

  def handle_cast({:disconnect, other_id}, state) do
    new_state = %{state | connections: List.delete(state.connections, other_id)}
    broadcast(new_state)
    {:noreply, new_state}
  end

  defp broadcast(state) do
    Phoenix.PubSub.broadcast(ChaosPlayground.PubSub, "nodes", {:node_updated, state})
  end
end
