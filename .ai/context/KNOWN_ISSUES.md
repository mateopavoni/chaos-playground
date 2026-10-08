# KNOWN_ISSUES.md

**Última verificación:** 2026-10-07. Severidad explícita por ítem. Los bugs encontrados se arreglaron el mismo día (sección *Arreglados*); lo que sigue abierto está marcado como tal.

---

## ✅ Arreglados el 2026-10-07 (los de código tienen test)

| Problema | Cómo se verificó antes | Arreglo |
|---|---|---|
| **Procesos de invitados nunca se limpiaban**: 200 `user_id` → 402 procesos, para siempre | script en entorno de test | `Engine.Reaper` (`engine/reaper.ex`): cada minuto baja el engine y los nodos de quien lleva 5 min sin pestañas conectadas (`Presence`); reconectar cancela la baja. `reaper_test.exs` |
| **El CSP bloqueaba todos los `<script>` inline**: toggle de tema roto, GA sin configurar, y **también onboarding/ayuda/demo guiada** (un `<script>` de ~300 líneas en `playground_live.html.heex`) | Playwright/Chromium sobre el código viejo: `data-theme` nunca se seteaba, 4 violaciones de CSP; prueba aislada en Firefox | Los scripts pasaron a `priv/static/theme.js` y `priv/static/guided-demo.js` (servidos desde `'self'`); el CSP ya no incluye Google. `csp_test.exs` falla si vuelve a aparecer un `<script>` inline |
| `revive_node` sobre un nodo vivo crasheaba la LiveView (`{:ok, _} =`) | `start_node` devuelve `already_started` (probado) | El caso `already_started` es un no-op |
| Latencia sin tope → `{:exit, :timeout}` en el paquete (probado con 6000 ms) | script en entorno de test | `NodeServer.set_latency/3` topa en 2000 ms (igual que el slider). Test en `node_server_test.exs` |
| `kill_node`, `connect_nodes`, `set_entry_node` confiaban en ids del cliente | lectura de código | Se ignoran ids que no están en el canvas; la entrada de tráfico solo acepta load balancers de la topología. Tests en `playground_live_test.exs` |
| GA4 y Search Console hardcodeados (cualquiera que corriera el repo mandaba hits a la propiedad del dueño) | lectura de código | Se quitaron del layout y del CSP |
| Dominios de la demo en `runtime.exs` (`check_origin`), `sitemap.xml`, `robots.txt` | lectura de código | `check_origin` solo acepta `PHX_HOST`; se borró `sitemap.xml` |

## 🟡 Abierto — Sin tope global de engines ni de RPS entre sesiones **[INFERENCIA]**
El tope de 200 RPS es por engine y el Reaper solo limpia engines abandonados: N invitados activos a la vez × 200 RPS sigue multiplicando la carga. Antes de exponer el proyecto a internet habría que agregar un tope global (de engines y/o de RPS total) o un rate limit al crear invitados.

## ✅ Dependencias — avisos de seguridad **[APLICADO]**

`mix hex.audit` el 2026-10-07 encontró 6 avisos. Se actualizaron con `mix deps.update` y ahora reporta *"No retired or security advisory packages found"*; la suite (108 tests) y `compile --warnings-as-errors` siguen verdes.

| Paquete | Aviso | Severidad | ¿Aplicaba? |
|---|---|---|---|
| `bandit` 1.12.0 → 1.12.5 | HTTP/2: ventana de conexión agotada fija procesos de Plug | **HIGH** | Sí: es el servidor HTTP de la app |
| `bandit` | CPU cuadrática al reensamblar mensajes WebSocket fragmentados | **HIGH** | Sí: LiveView usa WebSocket |
| `bandit` | Valores de header HTTP/2 con CR/LF/NUL sin validar | MEDIA | Sí |
| `postgrex` 0.22.3 → 0.22.4 | SQLi vía opción `:comment` de `Postgrex.stream/4` | MEDIA | No: el código no usa `:comment` |
| `phoenix_live_view` 1.2.7 → 1.2.12 | Open redirect en `validate_local_url!/2` con TAB/LF/CR | BAJA | Sin evidencia de uso directo |
| `lazy_html` 0.1.12 → 0.1.13 | XSS por mutación en serialización de SVG/MathML | BAJA | Solo en tests |

El update subió también `phoenix` 1.8.9 → 1.8.15 y algunas transitivas. **No aplicado:** `hammer` 7.4→7.5, `phoenix_live_dashboard`, `phoenix_live_reload`, `telemetry_metrics`, `dns_cluster` (sin avisos).

## ✅ Secretos — historia limpia **[FACT]**

Se escanearon las **127 revisiones** de todas las ramas (`git rev-list --all`):
- El único archivo de tipo sensible por nombre que alguna vez estuvo versionado es `.env.example` (plantilla con placeholders).
- Patrones de credenciales (AWS, GitHub PAT, Slack, claves privadas PEM, URLs de DB con contraseña): solo matchean placeholders (`ecto://USER:PASS@HOST` en un mensaje de error de `runtime.exs`, `postgres:postgres@localhost` en la plantilla).
- Las dos únicas cadenas base64 largas son las `secret_key_base` de **`config/dev.exs` y `config/test.exs`** — claves de desarrollo, públicas por diseño del scaffold de Phoenix. `runtime.exs` exige `SECRET_KEY_BASE` por variable de entorno en prod, sin valor por defecto.
- `signing_salt` (sesión y LiveView) están en el código; los salts no son secretos, pero conviene que sean distintos por proyecto, no copiados.
No se purgó nada de la historia porque no hay nada que purgar.

## ✅ Calidad **[APLICADO]**
`mix format` aplicado a 6 archivos que no cumplían (`user_auth.ex`, `topologies.ex`, `rate_limit_auth.ex`, `playground_live.html.heex`, `layouts.ex`, `registration.ex`); solo cambia formato. 4 tests de LiveView que esperaban mensajes de Ecto en inglés se corrigieron al español (el locale forzado a `es` desde `1dd0151` los había dejado desactualizados). `mix compile --warnings-as-errors` pasa.

---

## ⚪ INFO

- Un secret `DOKKU_SSH_PRIVATE_KEY` casi seguro sigue en los *Secrets* del repo en GitHub (el workflow que lo usaba se borró). **No verificable desde acá.** Ver `OPEN_QUESTIONS.md`.
- Docs viejas contradecían el código: README, `ARCHITECTURE.md` y `PORTFOLIO.md` (meta local) decían "engine global compartido" (falso desde `f1d6998`), el README decía "CI/CD corriendo los tests en cada push" (el único workflow solo desplegaba) y "demo guiada de 30s" (la UI dice 45 s). Ya se corrigieron README y `ARCHITECTURE.md`.
- El README citaba una tabla de Lighthouse medida sobre la demo en vivo y enlazaba a una sección `#performance` que ya no existía; la fila se quitó (no es reproducible sin la demo).
- La compose local no recarga el navegador al editar (la imagen `elixir:1.17` no trae `inotify-tools`); el código sí se recompila al refrescar.
- Dependencias con versión nueva sin avisos de seguridad y sin actualizar: `hammer`, `phoenix_live_dashboard`, `phoenix_live_reload`, `telemetry_metrics`, `dns_cluster`.
