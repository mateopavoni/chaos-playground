<div align="center">
  <h1>Chaos Playground</h1>
  <p>Armá una topología de infraestructura y sometela a tráfico y fallas reales, en vivo.</p>
  <p>
    <strong><a href="https://chaos-playground.mateopavoni.com.ar">🔗 Probar en vivo</a></strong>
    — sin cuenta, sin instalar nada. Al entrar hay una demo guiada de 30s.
  </p>
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
- Dashboard en vivo: RPS global, latencia p99, tasa de error, con gráfico de las últimas 20s.
- Presets de arquitectura pre-armados y guardado de topologías propias.
- Demo guiada de 30s (botón en el panel de Tráfico) para probar el proyecto sin leer nada.

## Quickstart
```bash
docker compose up
```
App en http://localhost:4000. Detalle completo en [RUN.md](RUN.md).

## Demo
**En vivo:** https://chaos-playground.mateopavoni.com.ar — sin cuenta, sin instalar nada.
Al entrar por primera vez aparece un modal con la opción de correr una demo automática de 30s.

Local: `docker compose up` y entrar a http://localhost:4000.

Deployado con [Dokku](https://dokku.com/) (Dockerfile de producción en la raíz del repo,
`mix release` + Postgres vía plugin de dokku, TLS con Let's Encrypt).

## Manual de usuario

1. **Elegí un preset** ("Monolith vs Microservices" o "Primary/Replica DB + Load Balancer") o armá el
   tuyo arrastrando desde un nodo hasta otro para conectarlos.
2. **Tocá "Iniciar"** y subí el slider de RPS objetivo — vas a ver partículas viajando por las
   conexiones y las métricas del header moverse en tiempo real.
3. **Clic en un nodo** para abrir el Inspector: ahí lo matás de verdad ("Matar proceso"), le inyectás
   latencia o packet loss artificial, o lo reiniciás si ya está muerto.
4. **Clic en una conexión** para seleccionarla y eliminarla.
5. **Mirá el gráfico del header** (naranja = RPS, rojo punteado = % de error, últimos 20s) — subir el
   failure_rate o matar un nodo con tráfico dependiente tiene que mover esas líneas. Si no se mueven,
   algo dejó de funcionar.

El botón `?` junto al título abre esta misma guía dentro de la app. El botón "Demo guiada (30s)" del
panel de Tráfico corre este recorrido solo, en cualquier momento.

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
| v0.4.0 | 2026-07-21 | Identidad visual propia (tema oscuro por default, acento naranja, glow en nodos, transición circular en el toggle de tema), Portfolio Pack |
| v0.5.0 | 2026-07-21 | Deploy productivo (Dokku + Postgres + TLS), gráfico de RPS/error rate en tiempo real, modal de bienvenida + demo guiada automática, ayuda in-app |
