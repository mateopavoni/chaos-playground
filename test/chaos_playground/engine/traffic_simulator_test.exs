defmodule ChaosPlayground.Engine.TrafficSimulatorTest do
  use ExUnit.Case, async: false

  alias ChaosPlayground.Engine.{NodeSupervisor, TrafficSimulator}

  setup do
    entry = "lb-#{System.unique_integer([:positive])}"
    api = "api-#{System.unique_integer([:positive])}"
    {:ok, _} = NodeSupervisor.start_node(id: entry, type: :load_balancer)
    {:ok, _} = NodeSupervisor.start_node(id: api, type: :api_server)

    ChaosPlayground.Engine.NodeServer.connect(entry, api)
    Process.sleep(10)

    Phoenix.PubSub.subscribe(ChaosPlayground.PubSub, "metrics")

    on_exit(fn -> TrafficSimulator.pause_traffic() end)

    %{entry: entry, api: api}
  end

  test "routes generated packets through connected nodes and broadcasts results", %{entry: entry} do
    TrafficSimulator.set_entry_node(entry)
    TrafficSimulator.set_rps(50)
    TrafficSimulator.start_traffic()

    assert_receive {:packet_result, %{status: :success}}, 1_000
  end

  test "does not generate traffic while paused" do
    TrafficSimulator.set_entry_node("unused")
    TrafficSimulator.pause_traffic()

    refute_receive {:packet_result, _}, 300
  end
end
