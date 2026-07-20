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

  @spec apply!(t()) :: t()
  def apply!(topology) do
    NodeSupervisor.list_node_ids() |> Enum.each(&NodeSupervisor.kill_node/1)

    Enum.each(topology.nodes, fn n ->
      {:ok, _pid} = NodeSupervisor.start_node(id: n.id, type: n.type)
    end)

    Enum.each(topology.connections, fn [from, to] -> NodeServer.connect(from, to) end)

    TrafficSimulator.set_topology(topology)
    Phoenix.PubSub.broadcast(ChaosPlayground.PubSub, "topology", {:topology_changed, topology})

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
