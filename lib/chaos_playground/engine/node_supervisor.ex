defmodule ChaosPlayground.Engine.NodeSupervisor do
  @moduledoc """
  DynamicSupervisor de NodeServer: un hijo por nodo del canvas.
  """

  use DynamicSupervisor

  alias ChaosPlayground.Engine.{NodeRegistry, NodeServer}

  def start_link(_opts), do: DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)

  @impl true
  def init(:ok), do: DynamicSupervisor.init(strategy: :one_for_one)

  @spec start_node(keyword()) :: DynamicSupervisor.on_start_child()
  def start_node(attrs), do: DynamicSupervisor.start_child(__MODULE__, {NodeServer, attrs})

  @doc "Termina el proceso real del nodo — la acción de chaos 'Kill Process'."
  @spec kill_node(String.t()) :: :ok | {:error, :not_found}
  def kill_node(node_id) do
    case NodeRegistry.whereis(node_id) do
      nil ->
        {:error, :not_found}

      pid ->
        NodeServer.mark_dead(node_id)
        Process.exit(pid, :kill)
        :ok
    end
  end

  @spec list_node_ids() :: [String.t()]
  def list_node_ids do
    Registry.select(NodeRegistry, [{{:"$1", :_, :_}, [], [:"$1"]}])
  end
end
