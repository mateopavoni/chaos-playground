defmodule ChaosPlayground.Engine.UserEngineSupervisor do
  @moduledoc """
  Arranca, al vuelo, el TrafficSimulator + ChaosMonkey de un usuario la primera vez
  que abre el playground. `ensure_started/1` es idempotente — un segundo mount
  (otra pestaña del mismo usuario) encuentra los procesos ya vivos.
  """

  use DynamicSupervisor

  alias ChaosPlayground.Engine.{ChaosMonkey, TrafficSimulator}

  def start_link(_opts), do: DynamicSupervisor.start_link(__MODULE__, :ok, name: __MODULE__)

  @impl true
  def init(:ok), do: DynamicSupervisor.init(strategy: :one_for_one)

  @spec ensure_started(term()) :: :ok
  def ensure_started(user_id) do
    start_child({TrafficSimulator, user_id})
    start_child({ChaosMonkey, user_id})
    :ok
  end

  defp start_child(child_spec) do
    case DynamicSupervisor.start_child(__MODULE__, child_spec) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
    end
  end
end
