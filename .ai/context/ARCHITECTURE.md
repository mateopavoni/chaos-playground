# ARCHITECTURE.md

**Última verificación:** 2026-10-07. Complementa (y corrige) el `ARCHITECTURE.md` de la raíz, que tenía el modelo de engine desactualizado.

## Árbol de supervisión (FACT, leído de `application.ex`)
```
ChaosPlayground.Supervisor (one_for_one)
├── Telemetry, Repo (Ecto), DNSCluster, Phoenix.PubSub, Presence, RateLimit (Hammer ETS)
├── Engine.NodeRegistry          Registry: {user_id, node_id} -> pid
├── Engine.NodeSupervisor        DynamicSupervisor: un NodeServer por nodo, restart: :temporary
├── Engine.EngineRegistry        Registry: TrafficSimulator y ChaosMonkey por usuario
├── Engine.UserEngineSupervisor  DynamicSupervisor: por usuario arranca TrafficSimulator + ChaosMonkey
├── Engine.Reaper                Baja el engine de quien lleva 5 min sin pestañas conectadas (revisa cada 1 min)
└── Endpoint
```
Un `user_id` es el id del usuario logueado **o** un `guest_id` (UUID en la cookie de sesión) si no hay login — ver `UserAuth.ensure_guest_id/2`. Cada `user_id` tiene su propio engine aislado. Las pestañas del mismo usuario comparten ese engine.

## Flujo de un paquete (FACT)
`TrafficSimulator` tickea cada 200 ms → por cada tick lanza `rps * 0.2` `Task`s escalonados dentro de la ventana → cada Task llama `NodeServer.handle_packet` (que duerme `latency_ms` y falla con probabilidad `failure_rate`) → si pasa, elige un vecino al azar de `connections` y repite; si falla, emite métrica de error. Cada hop se publica por PubSub (`packets:<user_id>`) y el hook JS lo anima.

## PubSub
Topics por usuario: `nodes:<id>`, `packets:<id>`, `metrics:<id>`, `topology:<id>`, más `playground:visitors:<id>` para Presence. `PlaygroundLive` se suscribe a todos al conectar.

## Pipeline web (FACT, `endpoint.ex` + `router.ex`)
`Plug.Static` → **`RemoteIp`** (reescribe `remote_ip` desde `X-Forwarded-For`; sin esto todos los clientes parecerían la IP del proxy) → `RequestLogger` → `Parsers` → `Session` (cookie firmada, `secure` solo en prod) → `Router`.
`:browser` agrega CSRF, un CSP estricto (`script-src 'self'`, `style-src 'self'`: **nada inline**; los scripts viven en `priv/static/theme.js` y `guided-demo.js`), `fetch_current_scope_for_user` y `ensure_guest_id`.

Rutas: `/` (PlaygroundLive), `/users/register`, `/users/log-in`, `/users/settings` (requiere login), `POST /users/log-in`, `DELETE /users/log-out`, `POST /users/update-password`; `/dev/dashboard` solo en dev.

## Rate limits (FACT)
- Login: 20/min por IP y 5/min por email (claves separadas), plug `RateLimitAuth`.
- Registro: por IP, dentro de la LiveView (el socket no pasa por el plug `RemoteIp`, así que resuelve la IP a mano desde `x_headers`).
- Guardar topología: 10/min por usuario.
- **No hay límite global** de engines simultáneos ni de RPS total (el `Reaper` solo limpia los abandonados; ver `KNOWN_ISSUES.md`).

## Cómo se corre localmente
`docker-compose.yml`: servicio `db` (Postgres 16, sin puertos publicados) + `app` (`elixir:1.17`, código montado, **modo dev**). Corre `deps.get`, `assets.setup`, `ecto.setup`, `phx.server`. Puerto en `127.0.0.1:4000`. Decisión de usar modo dev y no el release: ver `DECISIONS.md`.

## Historial de deploy (para no re-descubrirlo)
Producción fue un Dokku propio en una VPS de Oracle (ARM64) con nginx delante; GitHub Actions hacía push forzado al remoto `dokku` en cada push a `main`. **Todo eso está dado de baja.** La app ya no existe en el servidor (verificado el 2026-10-07: `dokku apps:list` no la lista) y ese día se borraron del repo `.github/workflows/deploy.yml` y `app.json` (hook de migración de Dokku). El `Dockerfile` (release multi-stage, `MIX_ENV=prod`) sigue en el repo pero **no se probó su build en esta auditoría**.
