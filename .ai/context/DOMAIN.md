# DOMAIN.md

**Última verificación:** 2026-10-07 (leído del código; las constantes se confirmaron en `traffic_simulator.ex`, `chaos_monkey.ex`, `playground_live.ex`).

## Nodos
Tipos: `:load_balancer`, `:api_server`, `:database`, `:cache`, `:queue` (etiquetas de UI: LB, API, DB, CACHE, MQ).
Estado de un `NodeServer`: `id`, `type`, `status` (`:healthy | :degraded | :dead`), `latency_ms >= 0`, `failure_rate` en `[0.0, 1.0]`, `connections` (lista de ids destino).
- Un paquete que falla (`:rand.uniform() < failure_rate`) deja el nodo `:degraded`; uno que pasa lo deja `:healthy`.
- `:dead` solo se llega por "matar proceso". Los nodos son `restart: :temporary`: **no revive solos**.
- Las conexiones viven solo en cada `NodeServer.connections`, no hay una lista de aristas aparte.

## Topologías
Un mapa `%{name, entry_node, nodes: [%{id, type, x, y}], connections: [[from, to]]}`. Mismo shape para presets built-in y guardados.
- 4 presets built-in: "Monolith vs Microservices", "Primary/Replica DB + Load Balancer", "Single Point of Failure", "Cola de eventos con workers". Se pueden linkear con `/?preset=<nombre exacto>`.
- Candidatos de entrada de tráfico: solo nodos `:load_balancer`.
- Aplicar una topología mata todos los nodos del usuario (esperando su baja real, hasta 1 s), arranca los nuevos, los conecta y avisa por PubSub.

## Reglas y límites (FACT)
| Regla | Valor | Dónde se aplica |
|---|---|---|
| RPS máximo | 200 | `TrafficSimulator` y `PlaygroundLive` |
| Tick del motor | 200 ms | `TrafficSimulator` |
| Animación de un hop | 350 ms fija (no depende de la latencia del nodo) | `TrafficSimulator` |
| Chaos Monkey | mata 1 nodo vivo al azar cada 6 s si está prendido | `ChaosMonkey` |
| Ventana de métricas | 2 s, recalculada cada 500 ms; historial de 40 puntos | `PlaygroundLive` |
| Conexión que cierra un ciclo | rechazada con flash de error | `PlaygroundLive.creates_cycle?/3` |
| Nombre de topología guardada | 1–60 caracteres | `SavedTopology` |
| Guardados por minuto | 10 por usuario | `PlaygroundLive` |
| Contraseña | 12–72 caracteres (bcrypt) | `User` |
| **Latencia máxima** | **sin tope** (ver `KNOWN_ISSUES.md`) | — |

## Métricas
`rps` = paquetes resueltos en el último segundo; `p99_ms` = percentil 99 de la latencia de la ventana; `error_rate` = errores / total en la ventana. Los paquetes crudos se acumulan en el process dictionary de la LiveView, no en assigns.

## Datos persistentes (Postgres)
- `users`, `users_tokens` (auth).
- `saved_topologies`: `name`, `entry_node`, `nodes` (array de maps/jsonb), `connections` (array de arrays de strings), `user_id`. Solo usuarios logueados guardan; cargar usa `String.to_existing_atom/1` sobre el `type` guardado.
- Los invitados no persisten nada: su estado es solo de procesos en memoria.
