defmodule ChaosPlayground.Engine.NodeServerTest do
  use ExUnit.Case, async: true

  alias ChaosPlayground.Engine.{NodeRegistry, NodeServer, NodeSupervisor}

  setup do
    user_id = System.unique_integer([:positive])
    id = "node-#{System.unique_integer([:positive])}"
    {:ok, _pid} = NodeSupervisor.start_node(user_id, id: id, type: :api_server)
    %{user_id: user_id, id: id}
  end

  test "starts healthy with defaults", %{user_id: user_id, id: id} do
    state = NodeServer.get_state(user_id, id)
    assert state.status == :healthy
    assert state.latency_ms == 0
    assert state.failure_rate == 0.0
    assert state.connections == []
  end

  test "is addressable via Registry regardless of caller", %{user_id: user_id, id: id} do
    assert is_pid(NodeRegistry.whereis(user_id, id))
    assert NodeRegistry.whereis(user_id, "does-not-exist") == nil
  end

  test "processes a packet successfully with zero failure rate", %{user_id: user_id, id: id} do
    assert {:ok, %{id: 1}} = NodeServer.handle_packet(user_id, id, %{id: 1})
    assert NodeServer.get_state(user_id, id).status == :healthy
  end

  test "always fails and reports :degraded when failure_rate is 1.0", %{
    user_id: user_id,
    id: id
  } do
    :ok = NodeServer.set_failure_rate(user_id, id, 1.0)
    Process.sleep(10)

    assert {:error, :node_failure} = NodeServer.handle_packet(user_id, id, %{id: 1})
    assert NodeServer.get_state(user_id, id).status == :degraded
  end

  test "tracks connections idempotently", %{user_id: user_id, id: id} do
    :ok = NodeServer.connect(user_id, id, "neighbor-a")
    :ok = NodeServer.connect(user_id, id, "neighbor-a")
    Process.sleep(10)

    assert NodeServer.get_state(user_id, id).connections == ["neighbor-a"]

    :ok = NodeServer.disconnect(user_id, id, "neighbor-a")
    Process.sleep(10)

    assert NodeServer.get_state(user_id, id).connections == []
  end

  test "operations against a missing node return {:error, :not_found}", %{user_id: user_id} do
    assert NodeServer.get_state(user_id, "ghost") == {:error, :not_found}
    assert NodeServer.handle_packet(user_id, "ghost", %{}) == {:error, :not_found}
  end
end
