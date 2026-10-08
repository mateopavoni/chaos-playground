defmodule ChaosPlayground.Engine.Reaper do
  @moduledoc """
  Termina los engines abandonados. Cada usuario/invitado arranca su TrafficSimulator +
  ChaosMonkey + NodeServers al primer mount (`UserEngineSupervisor.ensure_started/1`) y nada los
  detiene al cerrar la pestaña: cada cookie de invitado nueva dejaba procesos vivos para siempre,
  tickeando cada 200 ms. El Reaper revisa cada `@interval_ms` quién no tiene ninguna LiveView
  conectada (según `Presence`) y, pasado `@ttl_ms` sin visitantes, baja todo su engine.

  Reconectar antes del TTL cancela la baja; después del TTL, el siguiente mount vuelve a arrancar
  el engine desde cero (`ensure_started/1` es idempotente).
  """

  use GenServer

  alias ChaosPlayground.Engine.{
    EngineRegistry,
    NodeRegistry,
    NodeSupervisor,
    UserEngineSupervisor
  }

  alias ChaosPlaygroundWeb.Presence

  @interval_ms :timer.minutes(1)
  @ttl_ms :timer.minutes(5)

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc """
  Ejecuta una pasada de limpieza. `now` y `ttl_ms` son inyectables para poder testearla sin
  esperar minutos reales. Devuelve los user_ids cuyo engine se terminó.
  """
  @spec sweep(integer(), non_neg_integer()) :: [term()]
  def sweep(now \\ System.monotonic_time(:millisecond), ttl_ms \\ @ttl_ms),
    do: GenServer.call(__MODULE__, {:sweep, now, ttl_ms})

  @impl true
  def init(_opts) do
    schedule()
    {:ok, %{idle_since: %{}}}
  end

  @impl true
  def handle_call({:sweep, now, ttl_ms}, _from, state) do
    {reaped, state} = do_sweep(state, now, ttl_ms)
    {:reply, reaped, state}
  end

  @impl true
  def handle_info(:sweep, state) do
    {_reaped, state} = do_sweep(state, System.monotonic_time(:millisecond), @ttl_ms)
    schedule()
    {:noreply, state}
  end

  defp do_sweep(state, now, ttl_ms) do
    user_ids = EngineRegistry.list_user_ids()

    # Se parte de un mapa vacío (en vez de mutar el anterior) para olvidar a los usuarios cuyo
    # engine ya no existe.
    idle_since =
      Map.new(user_ids, fn user_id ->
        {user_id, if(visited?(user_id), do: nil, else: Map.get(state.idle_since, user_id, now))}
      end)

    expired = for {user_id, since} <- idle_since, since && now - since >= ttl_ms, do: user_id
    Enum.each(expired, &reap/1)

    {expired, %{state | idle_since: Map.drop(idle_since, expired)}}
  end

  defp visited?(user_id), do: Presence.list(Presence.visitors_topic(user_id)) != %{}

  defp reap(user_id) do
    # Re-chequeo justo antes de matar: si alguien reconectó entre la revisión y ahora, se salva.
    unless visited?(user_id) do
      for node_id <- NodeSupervisor.list_node_ids(user_id) do
        stop_child(NodeSupervisor, NodeRegistry.whereis(user_id, node_id))
      end

      for kind <- [:traffic_simulator, :chaos_monkey] do
        stop_child(UserEngineSupervisor, EngineRegistry.whereis(kind, user_id))
      end
    end
  end

  defp stop_child(_supervisor, nil), do: :ok

  defp stop_child(supervisor, pid) do
    DynamicSupervisor.terminate_child(supervisor, pid)
    :ok
  end

  defp schedule, do: Process.send_after(self(), :sweep, @interval_ms)
end
