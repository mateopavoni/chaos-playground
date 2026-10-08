defmodule ChaosPlayground.Engine.ReaperTest do
  # async: false — barre los engines de *todos* los usuarios sin visitantes; en paralelo
  # le bajaría el engine a otros tests que están corriendo.
  use ExUnit.Case, async: false

  alias ChaosPlayground.Engine.{
    EngineRegistry,
    NodeSupervisor,
    Presets,
    Reaper,
    Topology,
    UserEngineSupervisor
  }

  alias ChaosPlaygroundWeb.Presence

  @ttl 1_000

  setup do
    user_id = "reaper-#{System.unique_integer([:positive])}"
    UserEngineSupervisor.ensure_started(user_id)
    Topology.apply!(user_id, hd(Presets.list()))
    %{user_id: user_id}
  end

  defp alive?(user_id), do: EngineRegistry.whereis(:traffic_simulator, user_id) != nil

  test "baja el engine y los nodos de un usuario sin visitantes pasado el TTL", %{
    user_id: user_id
  } do
    assert NodeSupervisor.list_node_ids(user_id) != []

    refute user_id in Reaper.sweep(0, @ttl)
    assert alive?(user_id)

    assert user_id in Reaper.sweep(@ttl, @ttl)
    refute alive?(user_id)
    assert EngineRegistry.whereis(:chaos_monkey, user_id) == nil
    assert NodeSupervisor.list_node_ids(user_id) == []
  end

  test "no toca a un usuario con una pestaña conectada", %{user_id: user_id} do
    {:ok, _} = Presence.track(self(), Presence.visitors_topic(user_id), "tab-1", %{})

    Reaper.sweep(0, @ttl)
    refute user_id in Reaper.sweep(@ttl, @ttl)
    assert alive?(user_id)
  end

  test "un mount posterior vuelve a arrancar el engine", %{user_id: user_id} do
    Reaper.sweep(0, @ttl)
    Reaper.sweep(@ttl, @ttl)
    refute alive?(user_id)

    UserEngineSupervisor.ensure_started(user_id)
    assert alive?(user_id)
  end
end
