defmodule ChaosPlayground.Engine.NodeSupervisorTest do
  use ExUnit.Case, async: true

  alias ChaosPlayground.Engine.{NodeRegistry, NodeServer, NodeSupervisor}

  test "kill_node terminates the real process and it stays dead (restart: :temporary)" do
    id = "node-#{System.unique_integer([:positive])}"
    {:ok, pid} = NodeSupervisor.start_node(id: id, type: :database)
    ref = Process.monitor(pid)

    :ok = NodeSupervisor.kill_node(id)

    assert_receive {:DOWN, ^ref, :process, ^pid, :killed}
    # no auto-restart: the supervisor doesn't bring back a :temporary child
    refute Process.alive?(pid)

    # Registry limpia su ETS vía su propio monitor del proceso, en paralelo al
    # nuestro de arriba — no hay garantía de orden entre ambos, así que esperamos
    # un instante en vez de asumir que ya se desregistró.
    assert wait_until(fn -> NodeRegistry.whereis(id) == nil end)
    assert NodeServer.get_state(id) == {:error, :not_found}
  end

  test "kill_node on an unknown id returns {:error, :not_found}" do
    assert NodeSupervisor.kill_node("ghost") == {:error, :not_found}
  end

  test "kill_node broadcasts the node as dead so every viewer of the shared canvas sees it, not just the caller" do
    id = "node-#{System.unique_integer([:positive])}"
    {:ok, _pid} = NodeSupervisor.start_node(id: id, type: :api_server)
    Phoenix.PubSub.subscribe(ChaosPlayground.PubSub, "nodes")

    :ok = NodeSupervisor.kill_node(id)

    assert_receive {:node_updated, %NodeServer{id: ^id, status: :dead}}
  end

  defp wait_until(fun, attempts \\ 20) do
    cond do
      fun.() ->
        true

      attempts <= 0 ->
        false

      true ->
        Process.sleep(5)
        wait_until(fun, attempts - 1)
    end
  end

  test "list_node_ids includes every started node" do
    id = "node-#{System.unique_integer([:positive])}"
    {:ok, _pid} = NodeSupervisor.start_node(id: id, type: :cache)

    assert id in NodeSupervisor.list_node_ids()
  end
end
