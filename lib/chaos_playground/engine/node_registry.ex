defmodule ChaosPlayground.Engine.NodeRegistry do
  @moduledoc """
  Direcciona NodeServer por {user_id, node_id}. Nunca guardar el PID a mano en otro
  proceso: un NodeServer puede morir y volver a arrancar con un PID distinto.
  Clave compuesta por user_id para que el canvas de cada usuario sea independiente
  (dos usuarios pueden tener ambos un nodo "lb-1" sin pisarse).
  """

  def child_spec(_opts) do
    Registry.child_spec(keys: :unique, name: __MODULE__)
  end

  def via_tuple(user_id, node_id), do: {:via, Registry, {__MODULE__, {user_id, node_id}}}

  def whereis(user_id, node_id) do
    case Registry.lookup(__MODULE__, {user_id, node_id}) do
      [{pid, _value}] -> pid
      [] -> nil
    end
  end

  @spec list_node_ids(term()) :: [String.t()]
  def list_node_ids(user_id) do
    Registry.select(__MODULE__, [
      {{{user_id, :"$1"}, :_, :_}, [], [:"$1"]}
    ])
  end
end
