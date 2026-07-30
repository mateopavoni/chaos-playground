defmodule ChaosPlayground.Engine.ChaosMonkeyTest do
  # singleton global que lee/mata sobre la topologia global compartida (la misma que
  # playground_live_test.exs muta) — no puede correr en paralelo con esos tests.
  use ExUnit.Case, async: false

  alias ChaosPlayground.Engine.{ChaosMonkey, NodeServer, Presets, Topology}

  setup do
    Topology.apply!(hd(Presets.list()))
    on_exit(fn -> if ChaosMonkey.enabled?(), do: ChaosMonkey.toggle() end)
    :ok
  end

  test "toggle/0 flips the state and returns it" do
    refute ChaosMonkey.enabled?()
    assert ChaosMonkey.toggle() == true
    assert ChaosMonkey.enabled?()
    assert ChaosMonkey.toggle() == false
    refute ChaosMonkey.enabled?()
  end

  test "a tick kills a random alive node from the current topology when enabled" do
    Phoenix.PubSub.subscribe(ChaosPlayground.PubSub, "nodes")
    ChaosMonkey.toggle()

    send(ChaosMonkey, :tick)

    assert_receive {:node_updated, %NodeServer{status: :dead}}, 1000
  end

  test "a tick does nothing when disabled" do
    Phoenix.PubSub.subscribe(ChaosPlayground.PubSub, "nodes")
    refute ChaosMonkey.enabled?()

    send(ChaosMonkey, :tick)
    :sys.get_state(ChaosMonkey)

    refute_received {:node_updated, %NodeServer{status: :dead}}
  end
end
