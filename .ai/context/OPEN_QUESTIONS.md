# OPEN_QUESTIONS.md

**Última verificación:** 2026-10-07. Decisiones que quedaron sin resolver y requieren al dueño (Mateo Pavoni).

1. **Secret `DOKKU_SSH_PRIVATE_KEY` en GitHub.** El workflow que lo usaba se borró del repo, pero el secret casi seguro sigue en *Settings → Secrets and variables → Actions*, y su clave pública seguirá autorizada en la VPS si no se retiró. ¿Se borran ambos? (Acción manual: no hay acceso desde acá.)
2. **Remoto `dokku` en el clon local.** `git remote -v` aún lista el remoto de Dokku. ¿Se elimina con `git remote remove dokku`? **Cuidado mientras exista: cualquier `git fetch`/`push` contra ese remoto hace que Dokku cree la app `chaos-playground` en la VPS** (pasó durante esta auditoría; se revirtió con `dokku apps:destroy`, estaba vacía).
3. **¿Reactivar alguna vez?** Si sí, antes de exponerlo a internet: un tope global de engines/RPS entre sesiones (ver `KNOWN_ISSUES.md`), probar el `Dockerfile` en el entorno destino y revisar que `PHX_HOST` y `SECRET_KEY_BASE` estén configurados (`check_origin` ya solo acepta `PHX_HOST`).
4. **Captura/GIF de la demo** (`docs/screenshots/demo.png` pendiente en `TASKS.md`): útil para mostrar el proyecto ahora que no hay demo en vivo.
5. **Registros DNS de Cloudflare.** Los subdominios `chaos-playground.*` siguen resolviendo a la IP de la VPS por el wildcard `*.mateopavoni.com.ar`; el registro propio de `chaos-playground` se puede borrar.
6. **`PORTFOLIO.md` (gitignored)** todavía dice que el engine es un singleton global compartido: es falso desde `f1d6998`. No se publica, pero hay que corregirlo antes de reusar sus talking points en cualquier texto.
