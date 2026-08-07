defmodule ChaosPlayground.Engine.TrafficSimulator do
  @moduledoc """
  Engine central: tickea cada `@tick_ms`, genera paquetes en el nodo de entrada y los hace
  viajar por la topología siguiendo las `connections` de cada NodeServer (vía Registry).
  Cada paquete viaja en su propio Task para que el tráfico sea realmente concurrente entre sí.
  """

  use GenServer

  alias ChaosPlayground.Engine.{EngineRegistry, NodeServer}

  @tick_ms 200
  # ponytail: duración fija de la animación de un paquete viajando entre dos nodos —
  # desacoplada de la latencia simulada del nodo (esa ya se aplicó como delay real antes
  # de este hop). Subir a un cálculo dinámico si algún día importa que se vea "realista".
  @hop_animation_ms 350

  defstruct user_id: nil, running?: false, rps: 5, entry_node: nil, topology: nil

  # Client API

  def start_link(user_id),
    do: GenServer.start_link(__MODULE__, user_id, name: via(user_id))

  defp via(user_id), do: EngineRegistry.via_tuple(:traffic_simulator, user_id)

  def start_traffic(user_id), do: GenServer.cast(via(user_id), :start)
  def pause_traffic(user_id), do: GenServer.cast(via(user_id), :pause)

  def set_rps(user_id, rps) when is_integer(rps) and rps >= 0,
    do: GenServer.cast(via(user_id), {:set_rps, rps})

  def set_entry_node(user_id, node_id),
    do: GenServer.cast(via(user_id), {:set_entry_node, node_id})

  def set_topology(user_id, topology), do: GenServer.cast(via(user_id), {:set_topology, topology})
  def get_state(user_id), do: GenServer.call(via(user_id), :get_state)

  # Server callbacks

  @impl true
  def init(user_id) do
    schedule_tick()
    {:ok, %__MODULE__{user_id: user_id}}
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
      spawn_packets(state.user_id, state.entry_node, packets_per_tick(state.rps))
    end

    schedule_tick()
    {:noreply, state}
  end

  defp packets_per_tick(rps), do: round(rps * (@tick_ms / 1000))

  defp spawn_packets(_user_id, _entry_node, 0), do: :ok

  defp spawn_packets(user_id, entry_node, count) do
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
        route_packet(user_id, packet, entry_node)
      end)
    end)
  end

  defp route_packet(user_id, packet, node_id) do
    case NodeServer.handle_packet(user_id, node_id, packet) do
      {:ok, packet} ->
        broadcast_metric(user_id, :success, packet, node_id, nil)
        route_to_next_hop(user_id, packet, node_id)

      {:error, :not_found} ->
        :ok

      {:error, reason} ->
        broadcast_metric(user_id, :error, packet, node_id, reason)
    end
  end

  defp route_to_next_hop(user_id, packet, node_id) do
    case NodeServer.get_state(user_id, node_id) do
      %NodeServer{connections: [_ | _] = neighbors} ->
        next_id = Enum.random(neighbors)
        broadcast_hop(user_id, node_id, next_id)
        route_packet(user_id, packet, next_id)

      _ ->
        :ok
    end
  end

  defp broadcast_hop(user_id, from_id, to_id) do
    Phoenix.PubSub.broadcast(
      ChaosPlayground.PubSub,
      "packets:#{user_id}",
      {:packet_hop, %{from: from_id, to: to_id, duration_ms: @hop_animation_ms}}
    )
  end

  defp broadcast_metric(user_id, status, packet, node_id, reason) do
    latency_ms = System.monotonic_time(:millisecond) - packet.started_at

    Phoenix.PubSub.broadcast(
      ChaosPlayground.PubSub,
      "metrics:#{user_id}",
      {:packet_result,
       %{status: status, node_id: node_id, reason: reason, latency_ms: latency_ms}}
    )
  end

  defp schedule_tick, do: Process.send_after(self(), :tick, @tick_ms)
end
