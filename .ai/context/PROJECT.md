# PROJECT.md

**Última verificación:** 2026-10-07.

## Qué es
Playground de Chaos Engineering en el navegador. Cada nodo del canvas (load balancer, API server, base de datos, cache, cola) es un `GenServer` de Erlang/OTP real bajo un `DynamicSupervisor`. "Matar proceso" en la UI ejecuta `Process.exit(pid, :kill)` sobre ese proceso — la caída no es una animación. El tráfico es simulado: cada paquete viaja en su propio `Task` siguiendo las conexiones de cada nodo.

## Para quién
Proyecto de portfolio de **Mateo Pavoni** (Córdoba, Argentina). Su propósito es mostrar criterio con OTP/Phoenix LiveView, no resolver un problema de un cliente. Licencia propietaria: publicado solo para evaluación/portfolio (ver `LICENSE`).

## Stack (FACT, verificado 2026-10-07)
- Elixir 1.17, Phoenix 1.8.15, Phoenix LiveView 1.2.12, Bandit 1.12.5 (servidor HTTP).
- PostgreSQL 16 + Ecto (solo para cuentas y topologías guardadas).
- Tailwind 4.3.0 + esbuild 0.25.4. Sin framework JS: un `ColocatedHook` (`.NetworkCanvas`) anima el canvas.
- Auth tipo `phx.gen.auth` con scopes (bcrypt, sesión en cookie firmada, remember-me 14 días), rate limiting con Hammer (ETS).
- Todo corre con `docker compose up`; no hay que instalar Elixir en el host.

## Estado
**Archivado.** La demo pública (`chaos-playground.mateopavoni.com.ar`) y el deploy en Dokku están dados de baja (el dueño los bajó antes del 2026-10-07; ese día se verificó que la app ya no figura en el Dokku del VPS). El repo en GitHub sigue como vitrina de portfolio. Ver `CURRENT_STATE.md` para qué se verificó que funciona.

## Tamaño
95 archivos versionados, 127 commits (todos los autores son el dueño), 3 migraciones, 117 tests.

## Lo que NO es
- No es multi-nodo: todos los "nodos" son procesos en la misma BEAM (el roadmap de `ARCHITECTURE.md` menciona `libcluster` como idea).
- No tiene recuperación de contraseña (no hay mailer, a propósito).
- No tiene API JSON: todo es LiveView.
