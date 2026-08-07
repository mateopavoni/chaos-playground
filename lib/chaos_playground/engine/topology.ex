defmodule ChaosPlayground.Engine.Topology do
  @moduledoc """
  Materializa un mapa de topología (nodos + conexiones + entrada) en procesos OTP reales.
  Mismo shape para presets built-in (`ChaosPlayground.Engine.Presets`) y guardados (Ecto).
  """

  alias ChaosPlayground.Engine.{NodeServer, NodeSupervisor, TrafficSimulator}

  @type node_spec :: %{id: String.t(), type: atom(), x: number(), y: number()}
  @type t :: %{
          name: String.t(),
          nodes: [node_spec()],
          connections: [[String.t()]],
          entry_node: String.t()
        }

  @spec apply!(term(), t()) :: t()
  def apply!(user_id, topology) do
    NodeSupervisor.list_node_ids(user_id) |> Enum.each(&NodeSupervisor.kill_node(user_id, &1))

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
end
