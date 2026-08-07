defmodule ChaosPlayground.Engine.ChaosMonkeyTest do
  use ExUnit.Case, async: true

  alias ChaosPlayground.Engine.{
    ChaosMonkey,
    EngineRegistry,
    NodeServer,
    Presets,
    Topology,
    UserEngineSupervisor
  }

  setup do
    user_id = System.unique_integer([:positive])
    :ok = UserEngineSupervisor.ensure_started(user_id)
    Topology.apply!(user_id, hd(Presets.list()))
    on_exit(fn -> if ChaosMonkey.enabled?(user_id), do: ChaosMonkey.toggle(user_id) end)
    %{user_id: user_id, pid: GenServer.whereis(EngineRegistry.via_tuple(:chaos_monkey, user_id))}
  end

  test "toggle/1 flips the state and returns it", %{user_id: user_id} do
    refute ChaosMonkey.enabled?(user_id)
    assert ChaosMonkey.toggle(user_id) == true
    assert ChaosMonkey.enabled?(user_id)
    assert ChaosMonkey.toggle(user_id) == false
    refute ChaosMonkey.enabled?(user_id)
  end

  test "a tick kills a random alive node from the current topology when enabled", %{
    user_id: user_id,
    pid: pid
  } do
    Phoenix.PubSub.subscribe(ChaosPlayground.PubSub, "nodes:#{user_id}")
    ChaosMonkey.toggle(user_id)

    send(pid, :tick)

    assert_receive {:node_updated, %NodeServer{status: :dead}}, 1000
  end

  test "a tick does nothing when disabled", %{user_id: user_id, pid: pid} do
    Phoenix.PubSub.subscribe(ChaosPlayground.PubSub, "nodes:#{user_id}")
    refute ChaosMonkey.enabled?(user_id)

    send(pid, :tick)
    :sys.get_state(pid)

    refute_received {:node_updated, %NodeServer{status: :dead}}
  end
end
