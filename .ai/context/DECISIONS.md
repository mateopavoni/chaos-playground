# DECISIONS.md

**Última verificación:** 2026-10-07. Etiquetas: **(DECISION)** la tomó el dueño y quedó en el código/commits; **(AUDITORIA)** se tomó durante la auditoría del 2026-10-07 y se puede revertir.

## Fase 3 — ¿vale la pena RAG o un subagente de mantenimiento?
**No.** El repo es chico (95 archivos), estable y archivado. No hay volumen de contexto que justifique RAG ni cambios frecuentes que justifiquen un subagente. Reconsiderar solo si el proyecto se reactiva y crece.

## Decisiones de diseño del motor

**(DECISION) Los nodos son `restart: :temporary`.** Un nodo matado queda muerto hasta una acción explícita. Si auto-revivieran, la UI mostraría la caída una fracción de segundo y no serviría como herramienta didáctica. Subir a `:transient` el día que haga falta auto-heal (comentado en `NodeServer`).

**(DECISION) Direccionar por `Registry`, no por PID.** Un proceso puede morir y volver con otro PID; el resto del sistema lo encuentra por id.

**(DECISION, commit `f1d6998`, 2026-08-07) Engine por usuario, no global.** El diseño original era un singleton compartido por todos los visitantes (aún lo dicen el README viejo y `PORTFOLIO.md` (meta local)). Se cambió a un engine por usuario/invitado porque cargar un preset o activar el Chaos Monkey le cambiaba el canvas a todo el mundo. Costo asumido: procesos de invitados sin limpieza (`KNOWN_ISSUES.md`). **Cualquier texto que diga "global/compartido por todos" es anterior a esta decisión y es falso.**

**(DECISION) Métricas en el process dictionary, agregadas cada 500 ms.** Un assign por paquete saturaría la LiveView a RPS alto; la frecuencia de render queda acotada sin importar el volumen.

**(DECISION) Inspector en vez de context menu.** Clic para seleccionar + panel lateral con las mismas acciones. Evita la lógica de posicionamiento de un menú flotante y funciona en touch.

**(DECISION) `ColocatedHook` para el JS del canvas.** El hook vive en el mismo `.heex` que el markup que anima; esbuild lo recolecta solo.

**(DECISION) Rechazar conexiones que cierran un ciclo.** Un ciclo haría que `route_to_next_hop` se llame a sí mismo para siempre por paquete.

## Producto y seguridad

**(DECISION, commit `3452f3c`) Canvas accesible sin login; el login solo para guardar presets.** De ahí el `guest_id` en la cookie.

**(DECISION) Sin recuperación de contraseña ni mailer.** Un link que nunca llega es peor que no ofrecerlo.

**(DECISION, commit `36db6ee`) `RemoteIp` y tope server-side de RPS.** El rate limiter por IP necesitaba la IP real detrás del proxy; el tope de 200 RPS se aplica en el engine, no solo en el slider.

## Baja del proyecto (2026-10-07)

**(AUDITORIA) Archivar y quitar el auto-deploy.** Se borraron `.github/workflows/deploy.yml` (push forzado a un Dokku que ya no existe: habría fallado en cada push) y `app.json` (hook de migración de Dokku). El `Dockerfile` se conservó.

**(AUDITORIA) Reaper con TTL de 5 min para engines abandonados.** Se apoya en `Presence` (ya existía) en vez de `terminate/2` de la LiveView, que no se ejecuta ante un cierre abrupto. Costo: hay hasta ~6 min de procesos huérfanos por visitante y no hay tope global.

**(AUDITORIA) Scripts inline → archivos estáticos, y se quitó GA4/Search Console.** El CSP estricto ya estaba; lo roto era el layout. Se prefirió archivos externos a un nonce por request para no depender de un plug extra. GA se quitó porque el proyecto está archivado y cualquiera que lo corriera en local mandaría hits a la propiedad del dueño.

**(AUDITORIA) La compose local usa modo dev, no el release.** Razones: el release en modo prod fuerza cookies `secure` (se fija en compilación con `Mix.env()`) y un `check_origin` con dominios hardcodeados en `runtime.exs`, lo que probablemente rompe la sesión y el WebSocket en `http://localhost` en algunos navegadores (INFERENCIA, no se probó el release). Modo dev evita ambos y deja el código montado. Costo: sin `inotify-tools` el live-reload del navegador no funciona.

**(AUDITORIA) Se actualizaron `bandit`, `postgrex`, `phoenix_live_view` y `lazy_html`** para cerrar avisos de seguridad (2 HIGH en Bandit), con `mix deps.update` solo sobre esos paquetes; arrastró `phoenix` (1.8.9 → 1.8.15) y otras transitivas: `hpax`, `plug_crypto`, `phoenix_pubsub`, `phoenix_template` (ver `git diff mix.lock`). No se hizo un `deps.update --all`. Detalle en `KNOWN_ISSUES.md`.
