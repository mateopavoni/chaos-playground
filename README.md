<div align="center">
  <h1>Chaos Playground</h1>
  <p>Armá una topología de infraestructura y sometela a tráfico y fallas reales, en vivo.</p>
</div>

## El problema
Los diagramas de arquitectura y las demos de chaos engineering casi siempre son estáticos o
simulados en el cliente. Acá cada nodo del canvas — load balancer, API server, DB, cache, queue —
es un proceso Erlang/OTP real corriendo en el servidor. Matar un nodo desde la UI termina su
proceso de verdad; la supervisión que lo revive (o no) es la de OTP, no una animación.

## Stack
| Tecnología | Por qué |
|---|---|
| Elixir + Phoenix LiveView | UI en tiempo real sin SPA aparte; el estado vive del lado del servidor, cerca de los procesos que representa |
| Erlang/OTP (GenServer, DynamicSupervisor, Registry) | modelo de dominio: cada nodo de red es un proceso supervisado, direccionable por id |
| PostgreSQL + Ecto | persistencia de presets de arquitectura guardados |
| Tailwind + JS Hook (Canvas/SVG) | panel de control server-driven + animación de partículas de paquetes, que sí necesita JS |

## Features
- Canvas interactivo de nodos y conexiones, con paquetes animados viajando entre ellos.
- Motor de tráfico configurable: RPS, latencia por nodo, tasa de fallas, packet loss.
- Chaos actions por nodo/cable: matar proceso, inyectar latencia, dropear paquetes.
- Dashboard en vivo: RPS global, latencia p99, tasa de error.
- Presets de arquitectura pre-armados y guardado de topologías propias.

## Quickstart
```bash
docker compose up
```
App en http://localhost:4000. Detalle completo en [RUN.md](RUN.md).

## Demo
Local: `docker compose up` y entrar a http://localhost:4000 — no requiere cuenta ni configuración.
Deploy sugerido: Fly.io (soporte nativo para Phoenix + Postgres, ver `mix release` en `ARCHITECTURE.md`
para el Dockerfile de producción).

<!-- docs/screenshots/demo.png — capturar el canvas con tráfico corriendo antes de publicar -->

## Architecture
Ver [ARCHITECTURE.md](ARCHITECTURE.md).

## Licencia
Software propietario — todos los derechos reservados. Ver [LICENSE](LICENSE).

## Changelog
| Versión | Fecha | Cambio |
|---------|-------|--------|
| v0.1.0 | 2026-07-20 | Scaffold inicial (Phoenix 1.8 LiveView, Ecto/Postgres, docker-compose de desarrollo) |
| v0.2.0 | 2026-07-20 | Motor OTP: nodos como GenServer supervisados, tráfico simulado con Task concurrente por paquete |
| v0.3.0 | 2026-07-20 | Canvas LiveView con drag-to-connect y partículas animadas, chaos actions, presets built-in + guardados en Postgres, dashboard de métricas |
