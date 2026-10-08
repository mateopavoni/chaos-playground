# Chaos Playground

> **Playground de Chaos Engineering y resiliencia de red** (al estilo Gremlin / Chaos Monkey)
> construido alrededor de un problema difícil: **demostrar "let it crash" sin simularlo**, con la
> garantía de que la caída de un nodo es real, no una animación. Cada nodo del canvas — load
> balancer, API server, DB, cache, queue — es un `GenServer` de Erlang/OTP real bajo un
> `DynamicSupervisor`; matar un nodo desde la UI es literalmente `Process.exit(pid, :kill)` sobre
> ese proceso, verificable leyendo el motor OTP, no solo prometido en este README.

![estado](https://img.shields.io/badge/estado-archivado-lightgrey)
![stack](https://img.shields.io/badge/stack-Elixir%20%C2%B7%20Phoenix%20LiveView%20%C2%B7%20PostgreSQL-2b2b2b)
![license](https://img.shields.io/badge/license-proprietary-red)

Stack: Elixir + Phoenix LiveView + PostgreSQL + Tailwind, un solo servicio. Se corre completo con `docker compose up`.

> **Estado: archivado.** La demo pública fue dada de baja y el proyecto ya no está deployado en ningún lado.
> Se corre entero en local con `docker compose up` (ver [Cómo correr](#cómo-correr)). Una vez levantado no hace
> falta cuenta: hay una demo guiada de 45s (botón en el panel de Tráfico) que arma una topología, genera tráfico
> y mata un nodo en vivo, sola. Login opcional solo para guardar tus propias topologías.

### Capturas
| Light | Dark |
|---|---|
| ![Canvas en tema claro, tráfico corriendo](docs/screenshots/canvas-light.png) | ![Canvas en tema oscuro, tráfico corriendo](docs/screenshots/canvas-dark.png) |

---

## ¿Qué resuelve?
Los diagramas de arquitectura y las demos de chaos engineering casi siempre son estáticos o
simulados del lado del cliente: una animación CSS de "paquete viajando" o un mock de "nodo caído"
que solo cambia un ícono. Acá no:

1. **Cada nodo del canvas es un proceso real, supervisado.** Load balancer, API server, DB, cache,
   queue — cada uno es un `GenServer` bajo un `DynamicSupervisor`, direccionable por id vía
   `Registry`. "Matar proceso" en la UI es literalmente `Process.exit(pid, :kill)` sobre ese proceso.
2. **La supervisión es la de OTP, no un mock.** Los hijos del supervisor son `restart: :temporary`
   a propósito: un nodo matado se queda muerto hasta que algo pide levantarlo nuevamente — la demo
   *muestra* el estado roto (para enseñar chaos engineering) en vez de un auto-heal invisible que lo
   tape.
3. **Cada visitante tiene su propio engine aislado** (por cuenta, o por cookie de invitado si no hay login):
   matar un nodo en tu canvas no afecta a nadie más. Las pestañas del mismo usuario sí comparten canvas en tiempo real.

## Features
- Canvas interactivo de nodos y conexiones (drag-to-connect), con paquetes animados viajando entre
  ellos — se achican solos (escala logarítmica) si el tramo se satura, para que no se vean pegados
  a RPS alto.
- Motor de tráfico configurable: RPS objetivo, latencia por nodo, tasa de fallas, packet loss.
- Chaos actions por nodo/cable desde un panel Inspector: matar proceso, inyectar latencia, dropear
  paquetes, eliminar una conexión.
- **Chaos Monkey**: toggle que mata un nodo vivo al azar cada 6s, sin intervención — chaos
  engineering en piloto automático.
- Dashboard en vivo: RPS global, latencia p99, tasa de error, con gráfico de las últimas 20s.
- Contador de pestañas conectadas a tu canvas (`Phoenix.Presence`).
- Presets de arquitectura pre-armados (con link directo por `?preset=`) y guardado de topologías
  propias en Postgres, con cuenta opcional.
- Demo guiada de 45s que resetea el canvas a un estado limpio antes de arrancar, sin importar qué
  había activado antes (Chaos Monkey, tráfico corriendo, nodos muertos).

### En números
| | |
|---|---|
| Tests | **117**, `mix test` (verificado en Docker, 0 fallas) |
| Rutas | **7** (canvas + registro/login/settings, sin API JSON aparte — todo LiveView) |
| Motor de tráfico | tick cada **200ms**, un `Task` concurrente por paquete en vuelo |
| Chaos Monkey | tick cada **6s** |

---

## Arquitectura (resumen)
```mermaid
graph TD
  App[Application Supervisor]
  App --> Repo[(PostgreSQL)]
  App --> PubSub["Phoenix.PubSub<br/>topics: nodes · metrics · topology"]
  App --> Registry[NodeRegistry]
  App --> Sup["NodeSupervisor<br/>DynamicSupervisor, restart: temporary"]
  Sup -->|"1 por nodo del canvas"| Node["NodeServer<br/>(GenServer)"]
  App --> Traffic["TrafficSimulator<br/>tick 200ms"]
  App --> Monkey["ChaosMonkey<br/>tick 6s"]
  App --> Presence[Presence]
  App --> Endpoint
  Endpoint --> Live["PlaygroundLive<br/>(1 por pestaña de browser)"]

  Traffic -. routea paquetes por .-> Node
  Monkey -. mata un nodo vivo al azar .-> Node
  Live <-. broadcast/subscribe .-> PubSub
```
Detalle completo y las decisiones detrás de cada pieza (por qué `restart: :temporary`, por qué el
engine es por usuario, por qué el context menu se resolvió con click + Inspector) en
[ARCHITECTURE.md](ARCHITECTURE.md).

---

## Cómo correr
```bash
docker compose up
```
App en http://localhost:4000. Toolchain 100% en Docker (imagen `elixir:1.17` + Postgres 16; el host
no necesita Elixir instalado). Detalle completo — tests, IEx y solución de problemas — en
[RUN.md](RUN.md).

## La demo guiada
El botón "Demo guiada (45s)" del panel de Tráfico no es un video ni un script grabado: dispara los
mismos eventos de LiveView que un usuario haría a mano (cargar preset, subir RPS, abrir el Inspector,
matar un nodo, cambiar la entrada de tráfico) contra el engine real, con callouts que explican cada
paso. Primer paso siempre: apaga el Chaos Monkey si estaba prendido y recarga una topología limpia,
así el recorrido es reproducible sin importar qué había antes en el canvas.

## Tests
```bash
docker compose run --rm -e MIX_ENV=test app sh -c "mix deps.get && mix test"
```
117 tests: procesos/concurrencia del motor OTP (estado, kill + cleanup de `Registry`, routing con
`Task`, pausa/resume), LiveView (`Phoenix.LiveViewTest`: mount, start/pause, kill de nodo, cambio de
preset), auth y rate limiting.

## Limitaciones conocidas
- **Un engine por usuario/invitado.** Cada cookie de invitado arranca sus propios procesos OTP. Un `Reaper`
  los baja a los 5 minutos sin ninguna pestaña conectada (según `Presence`), pero no hay un tope global de
  engines ni de RPS entre sesiones: antes de exponerlo a internet de nuevo habría que agregarlo. Detalle en
  `.ai/context/KNOWN_ISSUES.md`.
- **Sin recuperación de contraseña.** El login no envía email (no hay mailer instalado, a propósito
  — un link de recuperación que nunca llega es peor que no ofrecerlo). Quien pierde su contraseña,
  pierde el acceso a sus presets guardados.
- **Un nodo matado no revive solo.** `restart: :temporary` en el `DynamicSupervisor` es intencional
  — la demo muestra el estado roto en vez de taparlo con auto-heal invisible. "Reiniciar nodo" es
  siempre una acción manual.

## Licencia
© 2026 Mateo Pavoni. Software propietario, publicado solo con fines de evaluación/portfolio.
Prohibida su copia, redistribución o reuso sin autorización escrita. Ver [LICENSE](LICENSE).
