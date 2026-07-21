<div align="center">
  <h1>Architecture — chaos-playground</h1>
</div>

## Visión general
Aplicación Phoenix LiveView donde cada componente de infraestructura visible en el canvas
(load balancer, API server, DB, cache, queue) está respaldado por un proceso OTP real. La UI no
simula estado: lee y comanda procesos vivos.

## Diagrama de procesos
```
Application
├── ChaosPlayground.Repo                    (Ecto / Postgres — presets guardados)
├── ChaosPlayground.Engine.NodeRegistry     (Registry — direccionamiento por id de nodo)
├── ChaosPlayground.Engine.NodeSupervisor   (DynamicSupervisor — un NodeServer por nodo del canvas)
│     └── ChaosPlayground.Engine.NodeServer (GenServer, uno por nodo: id/type/status/latency/failure_rate/connections)
├── ChaosPlayground.Engine.TrafficSimulator (GenServer — singleton: topología activa, tick loop, RPS/entry_node)
├── Phoenix.PubSub                          (topics: "nodes", "packets", "metrics", "topology")
└── ChaosPlaygroundWeb.Endpoint
      └── ChaosPlaygroundWeb.PlaygroundLive (un proceso por pestaña de browser — todas comparten el engine)
```

## Por qué este diseño
- **Un nodo = un proceso, no una fila en una tabla en memoria.** La acción "Kill Process" llama
  `Process.exit(pid, :kill)` sobre el `NodeServer` real (`NodeSupervisor.kill_node/1`) — el "let it
  crash" que se muestra es el de verdad, no una animación.
- **Hijos del `DynamicSupervisor` con `restart: :temporary`, a propósito.** Un nodo matado queda muerto
  — el supervisor no lo revive solo. "Reiniciar nodo" es una acción explícita del usuario
  (`NodeSupervisor.start_node/1` con el mismo id + reconectar según la topología), para que la demo
  *muestre* el estado roto en vez de que OTP lo tape con auto-heal invisible.
- **`Registry` en vez de guardar PIDs a mano.** Un `NodeServer` puede reiniciarse y cambiar de PID; el
  resto del sistema lo direcciona siempre por `id` vía `{:via, Registry, {NodeRegistry, id}}`.
- **Estado global compartido, no por sesión.** `TrafficSimulator` guarda la topología activa (una sola,
  compartida por todos los browsers conectados) — es lo que hace que dos pestañas viendo el playground
  vean *el mismo* canvas en tiempo real: cambios de topología se re-broadcastean por el topic "topology"
  y cada `PlaygroundLive` (incluido el que originó el cambio) reacciona al mensaje, no a un assign local.
  Trade-off consciente: no hay aislamiento multi-usuario — es un playground de una sola sesión compartida,
  no una app multi-tenant.
- **Conexiones viven en `NodeServer.connections`, no duplicadas en la topología.** El layout (x/y por
  nodo) es fijo por preset, pero el cableado real (qué nodo conecta con cuál) es el que cada `NodeServer`
  reporta en su propio estado — así "conectar por drag" y "eliminar conexión" son un solo
  `NodeServer.connect/2` / `disconnect/2`, sin sincronizar una segunda copia del grafo.
- **`TrafficSimulator` centralizado en vez de que cada `NodeServer` genere su propio tráfico.** Un único
  control de RPS/pausa; cada paquete viaja en su propio `Task.start/1` (concurrencia real entre paquetes),
  siguiendo `connections` de nodo en nodo vía Registry.
- **Métricas: buffer en process dictionary, agregado cada 500ms — no un assign por paquete.** A RPS alto
  un `assign` (y re-render) por cada `{:packet_result, ...}` satura el LiveView. Los eventos crudos se
  acumulan en el process dictionary del propio `PlaygroundLive` y un tick propio (`Process.send_after`)
  calcula RPS/p99/error rate sobre una ventana de 2s cada 500ms — frecuencia de render acotada
  independiente del volumen de tráfico.
- **"Context menu" → selección + panel Inspector.** El pedido original habla de un context menu por
  nodo/cable; se implementó como clic para seleccionar + panel lateral con las mismas acciones (kill,
  latencia, packet loss, eliminar conexión). Evita toda la lógica de posicionamiento de un menú flotante
  (coordenadas de mouse, cierre al hacer clic afuera) sin perder ninguna acción pedida — y es más fácil
  de usar en mobile/touch, donde un context menu nativo no aplica.
- **`Phoenix.LiveView.ColocatedHook` (Phoenix 1.8) para el JS del canvas.** El hook `.NetworkCanvas` vive
  en el mismo `.heex` que el markup que anima, en vez de un archivo JS separado registrado a mano en
  `app.js` — el build de esbuild lo recolecta solo.

## Mapa de módulos
- `lib/chaos_playground/engine/` — ver `.claude/CLAUDE.md` (Mapa de archivos clave) para el detalle
  archivo por archivo del motor OTP + `topology.ex` (materializa topologías) + `presets.ex` (datos).
- `lib/chaos_playground/topologies.ex` + `topologies/saved_topology.ex` — persistencia Ecto de presets
  guardados por el usuario (`name`, `entry_node`, `nodes` jsonb, `connections`).
- `lib/chaos_playground_web/live/playground_live.ex` + `.html.heex` — única LiveView de la app: control
  de tráfico, presets, selección de nodo/cable, inspector con chaos actions, dashboard de métricas.
  El JS Hook `.NetworkCanvas` (colocado en el `.heex`) maneja drag-to-connect y la animación de
  partículas vía Web Animations API sobre una capa SVG marcada `phx-update="ignore"`.

## Qué seguiría (con más tiempo)
- **Circuit breaker real en `NodeServer`:** N fallos consecutivos → auto-`:degraded` con load shedding,
  cooldown para auto-recuperar, en vez de un `failure_rate` fijo hasta que alguien lo cambia a mano.
- **Chaos Monkey autónomo:** un proceso que mata/degrada nodos al azar en un intervalo configurable
  (toggle on/off), para que la demo se sostenga sola en un video sin intervención manual.
- **Cluster real con `libcluster`:** hoy todos los "nodos" son procesos en la misma BEAM; con 2+ nodos
  Erlang reales conectados (ej. Fly.io multi-región), "matar un nodo" podría significar matar una VM
  entera, no solo un proceso local.
- **Replay de incidentes:** loguear cada chaos action + tick de métricas en Postgres para poder
  reproducir un escenario guardado a velocidad variable.
