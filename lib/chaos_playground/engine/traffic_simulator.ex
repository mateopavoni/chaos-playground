defmodule ChaosPlayground.Engine.TrafficSimulator do
  @moduledoc """
  Engine central: tickea cada `@tick_ms`, genera paquetes en el nodo de entrada y los hace
  viajar por la topología siguiendo las `connections` de cada NodeServer (vía Registry).
  Cada paquete viaja en su propio Task para que el tráfico sea realmente concurrente entre sí.
  """

  use GenServer

  alias ChaosPlayground.Engine.NodeServer

  @tick_ms 200
  # ponytail: duración fija de la animación de un paquete viajando entre dos nodos —
  # desacoplada de la latencia simulada del nodo (esa ya se aplicó como delay real antes
  # de este hop). Subir a un cálculo dinámico si algún día importa que se vea "realista".
  @hop_animation_ms 350

  defstruct running?: false, rps: 5, entry_node: nil, topology: nil

  # Client API

  def start_link(_opts), do: GenServer.start_link(__MODULE__, :ok, name: __MODULE__)

  def start_traffic, do: GenServer.cast(__MODULE__, :start)
  def pause_traffic, do: GenServer.cast(__MODULE__, :pause)

  def set_rps(rps) when is_integer(rps) and rps >= 0,
    do: GenServer.cast(__MODULE__, {:set_rps, rps})

  def set_entry_node(node_id), do: GenServer.cast(__MODULE__, {:set_entry_node, node_id})
  def set_topology(topology), do: GenServer.cast(__MODULE__, {:set_topology, topology})
  def get_state, do: GenServer.call(__MODULE__, :get_state)

  # Server callbacks

  @impl true
  def init(:ok) do
    schedule_tick()
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_call(:get_state, _from, state), do: {:reply, state, state}

  @impl true
  def handle_cast(:start, state), do: {:noreply, %{state | running?: true}}
  def handle_cast(:pause, state), do: {:noreply, %{state | running?: false}}
  def handle_cast({:set_rps, rps}, state), do: {:noreply, %{state | rps: rps}}

  def handle_cast({:set_entry_node, node_id}, state),
    do: {:noreply, %{state | entry_node: node_id}}

  def handle_cast({:set_topology, topology}, state),
    do: {:noreply, %{state | topology: topology, entry_node: topology.entry_node}}

  @impl true
  def handle_info(:tick, state) do
    if state.running? and state.entry_node do
      spawn_packets(state.entry_node, packets_per_tick(state.rps))
    end

    schedule_tick()
    {:noreply, state}
  end

  defp packets_per_tick(rps), do: round(rps * (@tick_ms / 1000))

  defp spawn_packets(_entry_node, 0), do: :ok

  defp spawn_packets(entry_node, count) do
    # ponytail: separa el arranque de cada paquete a lo largo de la ventana del tick
    # (en vez de lanzarlos todos en el mismo instante) para que dos paquetes en el
    # mismo camino no queden perfectamente superpuestos en el canvas — a RPS alto se
    # ven muchos mas puntos en vez de un solo punto "grueso".
    Enum.each(0..(count - 1), fn i ->
      packet = %{
        id: System.unique_integer([:positive, :monotonic]),
        started_at: System.monotonic_time(:millisecond)
      }

      delay = div(i * @tick_ms, count)

      Task.start(fn ->
        if delay > 0, do: Process.sleep(delay)
        route_packet(packet, entry_node)
      end)
    end)
  end

  defp route_packet(packet, node_id) do
    case NodeServer.handle_packet(node_id, packet) do
      {:ok, packet} ->
        broadcast_metric(:success, packet, node_id, nil)
        route_to_next_hop(packet, node_id)

      {:error, :not_found} ->
        :ok

      {:error, reason} ->
        broadcast_metric(:error, packet, node_id, reason)
    end
  end

  defp route_to_next_hop(packet, node_id) do
    case NodeServer.get_state(node_id) do
      %NodeServer{connections: [_ | _] = neighbors} ->
        next_id = Enum.random(neighbors)
        broadcast_hop(node_id, next_id)
        route_packet(packet, next_id)

      _ ->
        :ok
    end
  end

  defp broadcast_hop(from_id, to_id) do
    Phoenix.PubSub.broadcast(
      ChaosPlayground.PubSub,
      "packets",
      {:packet_hop, %{from: from_id, to: to_id, duration_ms: @hop_animation_ms}}
    )
  end

  defp broadcast_metric(status, packet, node_id, reason) do
    latency_ms = System.monotonic_time(:millisecond) - packet.started_at

    Phoenix.PubSub.broadcast(
      ChaosPlayground.PubSub,
      "metrics",
      {:packet_result,
       %{status: status, node_id: node_id, reason: reason, latency_ms: latency_ms}}
    )
  end

  defp schedule_tick, do: Process.send_after(self(), :tick, @tick_ms)
end
