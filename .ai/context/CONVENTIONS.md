# CONVENTIONS.md

**Última verificación:** 2026-10-07. Patrones observados en el código existente; seguilos al agregar código.

## Idioma
- **UI, flashes, mensajes de error de Ecto y comentarios: español rioplatense** ("Iniciá sesión", "esperá un momento"). El locale de Gettext está forzado a `es` (`config.exs`); los mensajes de Ecto salen traducidos, así que **un test que renderiza una LiveView debe afirmar el texto en español** (`"debe tener al menos 12 caracteres"`, `"ya está en uso"`). `errors_on/1` en tests de contexto no pasa por Gettext y sigue en inglés.
- Identificadores en inglés; nombres de dominio como en `DOMAIN.md`.

## Comentarios
Comentan el **por qué**, no el qué, y suelen nombrar el escenario que los motivó (ver `Topology.kill_and_await/2`, `Endpoint` sobre `RemoteIp`). Mantener ese estilo: un comentario que explique una decisión no obvia vale; uno que repite el código, no.

## Eventos de LiveView
Un `handle_event` puede dispararse a mano por el socket con cualquier payload, no solo desde el `<input>`. Por eso:
- Parsear con `Integer.parse/1` / `Float.parse/1`, nunca `String.to_integer/1`; valores inválidos → ignorar el evento (`{:noreply, socket}`), no crashear.
- Clampear en el servidor (`@max_rps`), aunque el slider ya tenga `max`.
- Los ids de nodo que llegan del cliente se validan contra `socket.assigns.nodes` / `entry_candidates` antes de actuar (`kill_node`, `connect_nodes`, `set_entry_node`); un id desconocido se ignora.

## Frontend y CSP
El CSP del router es `script-src 'self'; style-src 'self'`. **No agregar `<script>` ni `style=` inline** (el navegador los bloquea sin error visible en el servidor). El JS va en `assets/js/app.js` (bundle) o en un archivo de `priv/static/` listado en `static_paths/0`; `csp_test.exs` falla si aparece un `<script>` inline. Los hooks de LiveView usan `ColocatedHook`, que se extrae al bundle y no cuenta como inline.

## Procesos
- Direccionar siempre por `id` vía `Registry` (`NodeRegistry`, `EngineRegistry`), nunca guardar PIDs.
- Lo que cambia estado de un nodo hace `broadcast` por PubSub; la LiveView reacciona al mensaje en vez de mutar un assign local.
- Los hijos de nodo son `restart: :temporary` a propósito.

## Tests
- ExUnit + `Phoenix.LiveViewTest`; helpers en `test/support` (`ConnCase`, `DataCase`, fixtures de cuentas, `register_and_log_in_user`).
- Comando: `docker compose run --rm -e MIX_ENV=test app sh -c "mix deps.get && mix test"`. **Hace falta `MIX_ENV=test`**: el compose fija `MIX_ENV=dev` y Mix respeta la variable.
- `mix test` crea y migra la DB de test solo (alias en `mix.exs`).

## Formato y calidad
- `mix format` (hay un `.formatter.exs`); el repo quedó formateado el 2026-10-07. `mix compile --warnings-as-errors` pasa.
- Alias `mix precommit`: compile con warnings como errores + `deps.unlock --unused` + `format` + `test`.

## Commits
Conventional Commits en español/inglés mezclados: `feat:`, `fix:`, `fix(security):`, `chore(seo):`, `docs:`. Un cambio por commit.
