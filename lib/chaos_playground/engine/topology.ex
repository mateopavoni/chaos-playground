defmodule ChaosPlayground.Engine.Topology do
  @moduledoc """
  Materializa un mapa de topología (nodos + conexiones + entrada) en procesos OTP reales.
  Mismo shape para presets built-in (`ChaosPlayground.Engine.Presets`) y guardados (Ecto).
  """

  alias ChaosPlayground.Engine.{NodeRegistry, NodeServer, NodeSupervisor, TrafficSimulator}

  # Cuanto esperar a que un nodo matado termine de verdad (proceso caído + Registry
  # desregistrado) antes de rendirnos y seguir igual — ver kill_and_await/2.
  @kill_wait_ms 1_000

  @type node_spec :: %{id: String.t(), type: atom(), x: number(), y: number()}
  @type t :: %{
          name: String.t(),
          nodes: [node_spec()],
          connections: [[String.t()]],
          entry_node: String.t()
        }

  @spec apply!(term(), t()) :: t()
  def apply!(user_id, topology) do
    NodeSupervisor.list_node_ids(user_id) |> Enum.each(&kill_and_await(user_id, &1))

    Enum.each(topology.nodes, fn n ->
      {:ok, _pid} = NodeSupervisor.start_node(user_id, id: n.id, type: n.type)
    end)

    Enum.each(topology.connections, fn [from, to] -> NodeServer.connect(user_id, from, to) end)

    TrafficSimulator.set_topology(user_id, topology)

    Phoenix.PubSub.broadcast(
      ChaosPlayground.PubSub,
      "topology:#{user_id}",
      {:topology_changed, topology}
    )

    topology
  end

  @doc "Nodos con `type: :load_balancer` en la topología actual — candidatos válidos de entrada de tráfico."
  @spec entry_candidates(t()) :: [String.t()]
  def entry_candidates(topology) do
    topology.nodes
    |> Enum.filter(&(&1.type == :load_balancer))
    |> Enum.map(& &1.id)
  end

  # NodeSupervisor.kill_node/2 hace Process.exit(pid, :kill), que es async: el proceso
  # muere pero el Registry recién se desregistra vía su propio monitor, en paralelo
  # (ver node_supervisor_test.exs). Si la topología nueva reusa el mismo id (ej. clickear
  # el mismo preset dos veces seguidas, que es justo lo que hace el demo guiado),
  # start_node/2 de más abajo puede pisar al viejo todavía vivo y devolver
  # {:error, {:already_started, pid}}, reventando el `{:ok, _pid} =` — así que acá
  # esperamos la baja real (:DOWN) del proceso viejo antes de dejar arrancar el nuevo.
  defp kill_and_await(user_id, node_id) do
    case NodeRegistry.whereis(user_id, node_id) do
      nil ->
        :ok

      pid ->
        ref = Process.monitor(pid)
        NodeSupervisor.kill_node(user_id, node_id)

        receive do
          {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
        after
          @kill_wait_ms -> Process.demonitor(ref, [:flush])
        end
    end
  end
end
