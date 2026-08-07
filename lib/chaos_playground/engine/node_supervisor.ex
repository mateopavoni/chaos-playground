defmodule ChaosPlayground.Engine.NodeSupervisor do
  @moduledoc """
  DynamicSupervisor de NodeServer: un hijo por nodo del canvas.
  """

  use DynamicSupervisor

  alias ChaosPlayground.Engine.{NodeRegistry, NodeServer}

  def start_link(_opts), do: DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)

  @impl true
  def init(:ok), do: DynamicSupervisor.init(strategy: :one_for_one)

  @spec start_node(term(), keyword()) :: DynamicSupervisor.on_start_child()
  def start_node(user_id, attrs),
    do: DynamicSupervisor.start_child(__MODULE__, {NodeServer, [{:user_id, user_id} | attrs]})

  @doc "Termina el proceso real del nodo — la acción de chaos 'Kill Process'."
  @spec kill_node(term(), String.t()) :: :ok | {:error, :not_found}
  def kill_node(user_id, node_id) do
    case NodeRegistry.whereis(user_id, node_id) do
      nil ->
        {:error, :not_found}

      pid ->
        NodeServer.mark_dead(user_id, node_id)
        Process.exit(pid, :kill)
        :ok
    end
  end

  @spec list_node_ids(term()) :: [String.t()]
  def list_node_ids(user_id), do: NodeRegistry.list_node_ids(user_id)
end
