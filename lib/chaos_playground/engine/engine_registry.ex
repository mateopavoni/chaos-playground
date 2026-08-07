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
end
