defmodule ChaosPlayground.Engine.NodeRegistry do
  @moduledoc """
  Direcciona NodeServer por id. Nunca guardar el PID a mano en otro proceso:
  un NodeServer puede morir y volver a arrancar con un PID distinto.
  """

  def child_spec(_opts) do
    Registry.child_spec(keys: :unique, name: __MODULE__)
  end

  def via_tuple(node_id), do: {:via, Registry, {__MODULE__, node_id}}

  def whereis(node_id) do
    case Registry.lookup(__MODULE__, node_id) do
      [{pid, _value}] -> pid
      [] -> nil
    end
  end
end
