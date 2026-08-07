defmodule ChaosPlayground.Engine.TrafficSimulatorTest do
  use ExUnit.Case, async: true

  alias ChaosPlayground.Engine.{NodeSupervisor, TrafficSimulator, UserEngineSupervisor}

  setup do
    user_id = System.unique_integer([:positive])
    entry = "lb-#{System.unique_integer([:positive])}"
    api = "api-#{System.unique_integer([:positive])}"
    :ok = UserEngineSupervisor.ensure_started(user_id)
    {:ok, _} = NodeSupervisor.start_node(user_id, id: entry, type: :load_balancer)
    {:ok, _} = NodeSupervisor.start_node(user_id, id: api, type: :api_server)

    ChaosPlayground.Engine.NodeServer.connect(user_id, entry, api)
    Process.sleep(10)

    Phoenix.PubSub.subscribe(ChaosPlayground.PubSub, "metrics:#{user_id}")

    on_exit(fn -> TrafficSimulator.pause_traffic(user_id) end)

    %{user_id: user_id, entry: entry, api: api}
  end

  test "routes generated packets through connected nodes and broadcasts results", %{
    user_id: user_id,
    entry: entry
  } do
    TrafficSimulator.set_entry_node(user_id, entry)
    TrafficSimulator.set_rps(user_id, 50)
    TrafficSimulator.start_traffic(user_id)

    assert_receive {:packet_result, %{status: :success}}, 1_000
  end

  test "does not generate traffic while paused", %{user_id: user_id} do
    TrafficSimulator.set_entry_node(user_id, "unused")
    TrafficSimulator.pause_traffic(user_id)

    refute_receive {:packet_result, _}, 300
  end

  test "set_rps clamps above the 200 rps hard cap server-side, even bypassing the UI's max=\"200\"",
       %{user_id: user_id} do
    TrafficSimulator.set_rps(user_id, 999_999)

    # get_state is a synchronous call, so it serializes after the async set_rps cast above.
    assert TrafficSimulator.get_state(user_id).rps == 200
  end
end
