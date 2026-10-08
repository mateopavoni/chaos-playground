defmodule ChaosPlayground.Engine.EngineRegistry do
  @moduledoc """
  Direcciona TrafficSimulator/ChaosMonkey por {kind, user_id} — un par de procesos por
  usuario logueado en vez de un singleton global, para que el canvas de cada usuario
  sea independiente.
  """

  def child_spec(_opts) do
    Registry.child_spec(keys: :unique, name: __MODULE__)
  end

  def via_tuple(kind, user_id), do: {:via, Registry, {__MODULE__, {kind, user_id}}}

  @doc "Ids de todos los usuarios que tienen un engine (TrafficSimulator) vivo."
  def list_user_ids do
    Registry.select(__MODULE__, [{{{:traffic_simulator, :"$1"}, :_, :_}, [], [:"$1"]}])
  end

  @doc "Pid del proceso `kind` (:traffic_simulator | :chaos_monkey) del usuario, o nil."
  def whereis(kind, user_id) do
    case Registry.lookup(__MODULE__, {kind, user_id}) do
      [{pid, _}] -> pid
      [] -> nil
    end
  end
end
