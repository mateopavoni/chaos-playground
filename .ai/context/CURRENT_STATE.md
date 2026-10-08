# CURRENT_STATE.md

**Última verificación:** 2026-10-07. Esta tabla separa lo que se **ejecutó y observó** de lo que no.

## Verificado corriendo (FACT, 2026-10-07)
| Qué | Resultado |
|---|---|
| `docker compose up` desde cero (volumen de DB borrado) | `db` y `app` levantan; `app` pasa a `healthy` |
| Suite de tests (`MIX_ENV=test`) | **117 tests, 0 fallas** (108 originales + 9 nuevos para los arreglos) |
| `mix compile --force --warnings-as-errors` / `mix format --check-formatted` | OK |
| `mix hex.audit` | "No retired or security advisory packages found" |
| **Navegador real (Playwright + Chromium) contra la app en la compose** | PASS: LiveView conecta por WebSocket; onboarding aparece y "Explorar por mi cuenta" lo cierra; el tema se setea y el toggle alterna dark↔light; Iniciar tráfico → métricas con RPS > 0; matar un nodo → "Reiniciar nodo" → revive sin crash; Chaos Monkey ON; la demo guiada arranca y muestra callouts ("Paso 2/10"); **0 violaciones de CSP, 0 errores JS** |
| Historial de git | 127 revisiones previas, 1 autor, sin secretos (ver `KNOWN_ISSUES.md`) |

## NO verificado
- La demo guiada completa hasta el paso 10 (se observó que arranca y avanza).
- Arrastrar una conexión entre nodos (drag-to-connect) y guardar/cargar una topología con cuenta en el navegador (sí están cubiertos por tests de LiveView, no por el navegador).
- Safari/Firefox: el e2e fue solo en Chromium (Firefox solo se usó para una prueba aislada de CSP).
- Estado del repo remoto en GitHub: Secrets, branch protection (no hay acceso desde acá).

## Qué se hizo en la auditoría del 2026-10-07
- **Baja**: se quitaron `.github/workflows/deploy.yml` y `app.json` (auto-deploy a un Dokku que ya no existe); README archivado.
- **Local**: `docker-compose.yml` reescrito (la anterior no levantaba: chocaba el 5432 y no corría migraciones).
- **Seguridad**: 4 dependencias actualizadas (2 avisos HIGH en Bandit); historial escaneado sin secretos.
- **Bugs arreglados con tests**: engines de invitados sin limpieza (Reaper), CSP que bloqueaba scripts inline (tema, onboarding, demo guiada), `revive_node` crasheaba, latencia sin tope, handlers que confiaban en ids del cliente. Ver `KNOWN_ISSUES.md`.
- **Docs**: README, `RUN.md`, `ARCHITECTURE.md` corregidos; esta carpeta `.ai/` creada.
- Antes de empezar, `main` local estaba 11 commits atrás de `origin/main`; se sincronizó con `git merge --ff-only`. El remoto `dokku` quedó configurado en `.git/config` pero **no hay que hacer fetch/push contra él**: recrea la app en la VPS (ver `OPEN_QUESTIONS.md`).

## Funcionalidad implementada (según el código)
Canvas con drag-to-connect, 4 presets built-in, tráfico configurable (RPS ≤ 200, latencia, tasa de falla), Chaos Monkey, Inspector, métricas en vivo, demo guiada, registro/login/settings, guardado de topologías propias.

## Meta de fábrica desactualizada (gitignored, no se publica)
`PORTFOLIO.md` (talking points) todavía dice "singleton global" y "dos pestañas ven el mismo canvas / matar un nodo lo mata para todos": **falso** desde `f1d6998`. Ver `OPEN_QUESTIONS.md`. `TASKS.md` ya estaba cerrado salvo una captura/GIF pendiente.
