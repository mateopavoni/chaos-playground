defmodule ChaosPlayground.Engine.NodeServerTest do
  use ExUnit.Case, async: true

  alias ChaosPlayground.Engine.{NodeRegistry, NodeServer, NodeSupervisor}

  setup do
    id = "node-#{System.unique_integer([:positive])}"
    {:ok, _pid} = NodeSupervisor.start_node(id: id, type: :api_server)
    %{id: id}
  end

  test "starts healthy with defaults", %{id: id} do
    state = NodeServer.get_state(id)
    assert state.status == :healthy
    assert state.latency_ms == 0
    assert state.failure_rate == 0.0
    assert state.connections == []
  end

  test "is addressable via Registry regardless of caller", %{id: id} do
    assert is_pid(NodeRegistry.whereis(id))
    assert NodeRegistry.whereis("does-not-exist") == nil
  end

  test "processes a packet successfully with zero failure rate", %{id: id} do
    assert {:ok, %{id: 1}} = NodeServer.handle_packet(id, %{id: 1})
    assert NodeServer.get_state(id).status == :healthy
  end

  test "always fails and reports :degraded when failure_rate is 1.0", %{id: id} do
    :ok = NodeServer.set_failure_rate(id, 1.0)
    Process.sleep(10)

    assert {:error, :node_failure} = NodeServer.handle_packet(id, %{id: 1})
    assert NodeServer.get_state(id).status == :degraded
  end

  test "tracks connections idempotently", %{id: id} do
    :ok = NodeServer.connect(id, "neighbor-a")
    :ok = NodeServer.connect(id, "neighbor-a")
    Process.sleep(10)

    assert NodeServer.get_state(id).connections == ["neighbor-a"]

    :ok = NodeServer.disconnect(id, "neighbor-a")
    Process.sleep(10)

    assert NodeServer.get_state(id).connections == []
  end

  test "operations against a missing node return {:error, :not_found}" do
    assert NodeServer.get_state("ghost") == {:error, :not_found}
    assert NodeServer.handle_packet("ghost", %{}) == {:error, :not_found}
  end
end
