defmodule ChaosPlayground.Engine.NodeSupervisorTest do
  use ExUnit.Case, async: true

  alias ChaosPlayground.Engine.{NodeRegistry, NodeServer, NodeSupervisor}

  test "kill_node terminates the real process and it stays dead (restart: :temporary)" do
    user_id = System.unique_integer([:positive])
    id = "node-#{System.unique_integer([:positive])}"
    {:ok, pid} = NodeSupervisor.start_node(user_id, id: id, type: :database)
    ref = Process.monitor(pid)

    :ok = NodeSupervisor.kill_node(user_id, id)

    assert_receive {:DOWN, ^ref, :process, ^pid, :killed}
    # no auto-restart: the supervisor doesn't bring back a :temporary child
    refute Process.alive?(pid)

    # Registry limpia su ETS vía su propio monitor del proceso, en paralelo al
    # nuestro de arriba — no hay garantía de orden entre ambos, así que esperamos
    # un instante en vez de asumir que ya se desregistró.
    assert wait_until(fn -> NodeRegistry.whereis(user_id, id) == nil end)
    assert NodeServer.get_state(user_id, id) == {:error, :not_found}
  end

  test "kill_node on an unknown id returns {:error, :not_found}" do
    assert NodeSupervisor.kill_node(System.unique_integer([:positive]), "ghost") ==
             {:error, :not_found}
  end

  test "kill_node broadcasts the node as dead so every viewer of the same user's canvas sees it, not just the caller" do
    user_id = System.unique_integer([:positive])
    id = "node-#{System.unique_integer([:positive])}"
    {:ok, _pid} = NodeSupervisor.start_node(user_id, id: id, type: :api_server)
    Phoenix.PubSub.subscribe(ChaosPlayground.PubSub, "nodes:#{user_id}")

    :ok = NodeSupervisor.kill_node(user_id, id)

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

  test "list_node_ids includes only the calling user's nodes" do
    user_id = System.unique_integer([:positive])
    other_user_id = System.unique_integer([:positive])
    id = "node-#{System.unique_integer([:positive])}"
    other_id = "node-#{System.unique_integer([:positive])}"
    {:ok, _pid} = NodeSupervisor.start_node(user_id, id: id, type: :cache)
    {:ok, _pid} = NodeSupervisor.start_node(other_user_id, id: other_id, type: :cache)

    ids = NodeSupervisor.list_node_ids(user_id)
    assert id in ids
    refute other_id in ids
  end
end
