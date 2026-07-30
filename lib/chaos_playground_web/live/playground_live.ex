defmodule ChaosPlaygroundWeb.PlaygroundLive do
  use ChaosPlaygroundWeb, :live_view

  alias ChaosPlayground.Engine.{
    ChaosMonkey,
    NodeServer,
    NodeSupervisor,
    Presets,
    Topology,
    TrafficSimulator
  }
  alias ChaosPlayground.Topologies
  alias ChaosPlaygroundWeb.Presence

  @metrics_tick_ms 500
  @metrics_window_ms 2_000
  @history_max 40
  @presence_topic "playground:visitors"

  @impl true
  def mount(params, _session, socket) do
    if connected?(socket) do
      pubsub_subscribe()
      Phoenix.PubSub.subscribe(ChaosPlayground.PubSub, @presence_topic)
      {:ok, _} = Presence.track(self(), @presence_topic, socket.id, %{})
      Process.send_after(self(), :tick_metrics, @metrics_tick_ms)
      maybe_apply_preset_param(params["preset"])
    end

    # ponytail: buffer de paquetes crudos en el process dictionary, no en assigns —
    # a RPS alto no queremos un re-render por paquete, solo cada @metrics_tick_ms.
    Process.put(:metrics_buffer, [])

    engine = TrafficSimulator.get_state()
    topology = engine.topology || Topology.apply!(hd(Presets.list()))

    socket =
      socket
      |> assign(:topology, topology)
      |> assign(:nodes, load_nodes(topology))
      |> assign(:entry_candidates, Topology.entry_candidates(topology))
      |> assign(:entry_node, engine.entry_node || topology.entry_node)
      |> assign(:running?, engine.running?)
      |> assign(:chaos_monkey?, ChaosMonkey.enabled?())
      |> assign(:visitor_count, presence_count())
      |> assign(:rps, engine.rps)
      |> assign(:metrics, %{rps: 0, p99_ms: 0, error_rate: 0.0})
      |> assign(:metrics_history, [])
      |> assign(:builtin_presets, Presets.list())
      |> assign(:saved_presets, list_saved_presets(socket.assigns.current_scope))
      |> assign(:selected, nil)

    {:ok, socket}
  end

  defp pubsub_subscribe do
    for topic <- ~w(nodes packets metrics topology) do
      Phoenix.PubSub.subscribe(ChaosPlayground.PubSub, topic)
    end
  end

  defp presence_count, do: @presence_topic |> Presence.list() |> map_size() |> max(1)

  # Un ciclo (A->B->...->A) hace que TrafficSimulator.route_to_next_hop se llame a si mismo
  # para siempre por paquete — nada mas lo frena. Se rechaza la conexion si `to` ya puede
  # llegar de vuelta a `from` por las conexiones existentes.
  defp creates_cycle?(nodes, from, to), do: reaches?(nodes, to, from, MapSet.new())

  defp reaches?(_nodes, current, target, _visited) when current == target, do: true

  defp reaches?(nodes, current, target, visited) do
    if MapSet.member?(visited, current) do
      false
    else
      visited = MapSet.put(visited, current)

      case Map.get(nodes, current) do
        nil -> false
        %{connections: conns} -> Enum.any?(conns, &reaches?(nodes, &1, target, visited))
      end
    end
  end

  # ?preset=<nombre> permite linkear directo a un preset builtin (ej. para compartir
  # una topologia rota). Nombre invalido/ausente => no-op, se queda con lo que ya haya.
  defp maybe_apply_preset_param(nil), do: :ok

  defp maybe_apply_preset_param(name) do
    case Enum.find(Presets.list(), &(&1.name == name)) do
      nil -> :ok
      preset -> Topology.apply!(preset)
    end
  end

  defp load_nodes(topology) do
    Map.new(topology.nodes, fn spec ->
      state =
        case NodeServer.get_state(spec.id) do
          {:error, :not_found} ->
            %NodeServer{
              id: spec.id,
              type: spec.type,
              status: :dead,
              latency_ms: 0,
              failure_rate: 0.0,
              connections: []
            }

          state ->
            state
        end

      {spec.id, state}
    end)
  end

  # Control de tráfico

  @impl true
  def handle_event("start_traffic", _params, socket) do
    TrafficSimulator.start_traffic()
    {:noreply, assign(socket, :running?, true)}
  end

  def handle_event("pause_traffic", _params, socket) do
    TrafficSimulator.pause_traffic()
    {:noreply, assign(socket, :running?, false)}
  end

  def handle_event("set_rps", %{"rps" => rps}, socket) do
    rps = String.to_integer(rps)
    TrafficSimulator.set_rps(rps)
    {:noreply, assign(socket, :rps, rps)}
  end

  def handle_event("set_entry_node", %{"entry_node" => id}, socket) do
    TrafficSimulator.set_entry_node(id)
    {:noreply, assign(socket, :entry_node, id)}
  end

  def handle_event("toggle_chaos_monkey", _params, socket) do
    {:noreply, assign(socket, :chaos_monkey?, ChaosMonkey.toggle())}
  end

  # Presets

  def handle_event("load_preset", %{"name" => name}, socket) do
    preset = Enum.find(socket.assigns.builtin_presets, &(&1.name == name))
    if preset, do: Topology.apply!(preset)
    {:noreply, socket}
  end

  def handle_event("load_saved", %{"id" => id}, socket) do
    case socket.assigns.current_scope do
      nil ->
        {:noreply, put_flash(socket, :error, "Iniciá sesión para cargar tus presets guardados")}

      scope ->
        case Topologies.get(scope, id) do
          {:ok, saved} ->
            topology = %{
              name: saved.name,
              entry_node: saved.entry_node,
              nodes: atomize_nodes(saved.nodes),
              connections: saved.connections
            }

            Topology.apply!(topology)
            {:noreply, socket}

          {:error, :not_found} ->
            {:noreply, put_flash(socket, :error, "Preset no encontrado")}
        end
    end
  end

  def handle_event("save_topology", %{"name" => name}, socket) do
    case socket.assigns.current_scope do
      nil ->
        {:noreply, put_flash(socket, :error, "Iniciá sesión para guardar presets")}

      scope ->
        if under_save_rate_limit?(scope) do
          do_save_topology(socket, scope, name)
        else
          {:noreply,
           put_flash(socket, :error, "Estás guardando muy seguido, esperá un momento")}
        end
    end
  end

  # Selección (canvas)

  def handle_event("select_node", %{"id" => id}, socket) do
    {:noreply, assign(socket, :selected, {:node, id})}
  end

  def handle_event("select_edge", %{"from" => from, "to" => to}, socket) do
    {:noreply, assign(socket, :selected, {:edge, from, to})}
  end

  def handle_event("clear_selection", _params, socket) do
    {:noreply, assign(socket, :selected, nil)}
  end

  def handle_event("connect_nodes", %{"from" => from, "to" => to}, socket) when from != to do
    if creates_cycle?(socket.assigns.nodes, from, to) do
      {:noreply,
       put_flash(socket, :error, "Esa conexión cerraría un ciclo — el tráfico daría vueltas para siempre")}
    else
      NodeServer.connect(from, to)
      {:noreply, socket}
    end
  end

  def handle_event("connect_nodes", _params, socket), do: {:noreply, socket}

  def handle_event("disconnect_edge", %{"from" => from, "to" => to}, socket) do
    NodeServer.disconnect(from, to)
    {:noreply, assign(socket, :selected, nil)}
  end

  # Chaos actions

  def handle_event("kill_node", %{"id" => id}, socket) do
    NodeSupervisor.kill_node(id)
    nodes = Map.update!(socket.assigns.nodes, id, &%{&1 | status: :dead})
    {:noreply, assign(socket, :nodes, nodes)}
  end

  def handle_event("revive_node", %{"id" => id}, socket) do
    case node_position(socket.assigns.topology, id) do
      nil ->
        {:noreply, socket}

      spec ->
        {:ok, _pid} = NodeSupervisor.start_node(id: spec.id, type: spec.type)

        socket.assigns.topology.connections
        |> Enum.filter(fn [from, _to] -> from == id end)
        |> Enum.each(fn [_from, to] -> NodeServer.connect(id, to) end)

        {:noreply, socket}
    end
  end

  def handle_event("set_latency", %{"node_id" => id, "value" => value}, socket) do
    NodeServer.set_latency(id, String.to_integer(value))
    {:noreply, socket}
  end

  def handle_event("set_failure_rate", %{"node_id" => id, "value" => value}, socket) do
    {rate, _} = Float.parse(value)
    NodeServer.set_failure_rate(id, rate)
    {:noreply, socket}
  end

  # Eventos del engine (PubSub)

  @impl true
  def handle_info({:node_updated, node_state}, socket) do
    if Map.has_key?(socket.assigns.nodes, node_state.id) do
      {:noreply, assign(socket, :nodes, Map.put(socket.assigns.nodes, node_state.id, node_state))}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:packet_hop, hop}, socket) do
    {:noreply, push_event(socket, "packet_hop", hop)}
  end

  def handle_info({:packet_result, result}, socket) do
    entry = Map.put(result, :ts, System.monotonic_time(:millisecond))
    Process.put(:metrics_buffer, [entry | Process.get(:metrics_buffer, [])])
    {:noreply, socket}
  end

  def handle_info(%{event: "presence_diff"}, socket) do
    {:noreply, assign(socket, :visitor_count, presence_count())}
  end

  def handle_info({:topology_changed, topology}, socket) do
    socket =
      socket
      |> assign(:topology, topology)
      |> assign(:nodes, load_nodes(topology))
      |> assign(:entry_candidates, Topology.entry_candidates(topology))
      |> assign(:entry_node, topology.entry_node)
      |> assign(:selected, nil)

    {:noreply, socket}
  end

  def handle_info(:tick_metrics, socket) do
    Process.send_after(self(), :tick_metrics, @metrics_tick_ms)

    now = System.monotonic_time(:millisecond)
    window = Process.get(:metrics_buffer, []) |> Enum.filter(&(now - &1.ts <= @metrics_window_ms))
    Process.put(:metrics_buffer, window)

    metrics = compute_metrics(window, now)
    history = [metrics | socket.assigns.metrics_history] |> Enum.take(@history_max)

    {:noreply, socket |> assign(:metrics, metrics) |> assign(:metrics_history, history)}
  end

  defp compute_metrics([], _now), do: %{rps: 0, p99_ms: 0, error_rate: 0.0}

  defp compute_metrics(window, now) do
    total = length(window)
    errors = Enum.count(window, &(&1.status == :error))
    recent = Enum.count(window, &(now - &1.ts <= 1_000))
    latencies = window |> Enum.map(& &1.latency_ms) |> Enum.sort()

    %{
      rps: recent,
      p99_ms: percentile(latencies, 0.99),
      error_rate: Float.round(errors / total, 3)
    }
  end

  defp percentile([], _p), do: 0
  defp percentile(sorted, p), do: Enum.at(sorted, max(0, round(p * (length(sorted) - 1))))

  defp chart_points(history, key, width, height, max_v \\ nil) do
    values = history |> Enum.reverse() |> Enum.map(&Map.fetch!(&1, key))
    n = length(values)
    scale = max_v || Enum.max([Enum.max(values, fn -> 0 end), 1])
    # padding evita que un valor en el maximo/minimo corte el stroke contra el borde del viewBox
    pad = height * 0.15
    inner = height - 2 * pad

    values
    |> Enum.with_index()
    |> Enum.map(fn {v, i} ->
      x = if n <= 1, do: width, else: i / (n - 1) * width
      y = height - pad - min(v / scale, 1) * inner
      "#{Float.round(x * 1.0, 1)},#{Float.round(y * 1.0, 1)}"
    end)
    |> Enum.join(" ")
  end

  defp chart_area_points(history, key, width, height, max_v \\ nil) do
    case chart_points(history, key, width, height, max_v) do
      "" -> ""
      line -> "#{line} #{width},#{height} 0,#{height}"
    end
  end

  defp atomize_nodes(nodes) do
    Enum.map(nodes, fn n ->
      %{id: n["id"], type: String.to_existing_atom(n["type"]), x: n["x"], y: n["y"]}
    end)
  end

  defp changeset_summary(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, _opts} -> msg end)
    |> Enum.map_join(", ", fn {field, msgs} -> "#{field} #{Enum.join(msgs, ", ")}" end)
  end

  defp do_save_topology(socket, scope, name) do
    nodes =
      Enum.map(socket.assigns.topology.nodes, fn n ->
        %{"id" => n.id, "type" => Atom.to_string(n.type), "x" => n.x, "y" => n.y}
      end)

    connections =
      for {id, %{connections: conns}} <- socket.assigns.nodes, to <- conns, do: [id, to]

    attrs = %{
      name: name,
      entry_node: socket.assigns.entry_node,
      nodes: nodes,
      connections: connections
    }

    case Topologies.save(scope, attrs) do
      {:ok, _saved} ->
        socket =
          socket
          |> assign(:saved_presets, Topologies.list_saved(scope))
          |> put_flash(:info, "Preset \"#{name}\" guardado")

        {:noreply, socket}

      {:error, changeset} ->
        {:noreply,
         put_flash(socket, :error, "No se pudo guardar: #{changeset_summary(changeset)}")}
    end
  end

  defp under_save_rate_limit?(scope) do
    match?(
      {:allow, _},
      ChaosPlayground.RateLimit.hit("save_topology:user:#{scope.user.id}", :timer.minutes(1), 10)
    )
  end

  defp list_saved_presets(nil), do: []
  defp list_saved_presets(scope), do: Topologies.list_saved(scope)

  # Helpers de template

  defp node_position(topology, id), do: Enum.find(topology.nodes, &(&1.id == id))

  defp type_label(:load_balancer), do: "LB"
  defp type_label(:api_server), do: "API"
  defp type_label(:database), do: "DB"
  defp type_label(:cache), do: "CACHE"
  defp type_label(:queue), do: "MQ"

  defp node_fill_class(:healthy), do: "fill-status-healthy text-status-healthy"
  defp node_fill_class(:degraded), do: "fill-status-degraded text-status-degraded"
  defp node_fill_class(:dead), do: "fill-status-dead text-status-dead"

  defp status_badge_class(:healthy), do: "bg-status-healthy/20 text-status-healthy"
  defp status_badge_class(:degraded), do: "bg-status-degraded/20 text-status-degraded"
  defp status_badge_class(:dead), do: "bg-status-dead/20 text-status-dead"
end
