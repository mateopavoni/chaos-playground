defmodule ChaosPlayground.Engine.TopologyTest do
  use ExUnit.Case, async: true

  alias ChaosPlayground.Engine.{NodeSupervisor, Presets, Topology, UserEngineSupervisor}

  setup do
    user_id = System.unique_integer([:positive])
    :ok = UserEngineSupervisor.ensure_started(user_id)
    %{user_id: user_id}
  end

  test "reapplying the same topology back-to-back (same node ids) doesn't crash", %{
    user_id: user_id
  } do
    preset = Enum.find(Presets.list(), &(&1.name == "Single Point of Failure"))

    # Clicking the same preset twice in a row (the guided demo does exactly this) is the
    # scenario that exposed the race: apply!/2 kills every current node with
    # Process.exit(pid, :kill) (async — Registry deregisters later via its own monitor,
    # see node_supervisor_test.exs) and immediately starts new nodes with the same ids.
    # Without waiting for the old process to actually go down first, start_node/2 can hit
    # {:error, {:already_started, pid}} and crash the `{:ok, _pid} =` match below it.
    assert %{name: _} = Topology.apply!(user_id, preset)
    assert %{name: _} = Topology.apply!(user_id, preset)
    assert %{name: _} = Topology.apply!(user_id, preset)

    ids = NodeSupervisor.list_node_ids(user_id)
    assert Enum.sort(ids) == Enum.sort(Enum.map(preset.nodes, & &1.id))
  end
end
