# Índice — `.ai/context/`

Generado por una auditoría de context engineering el 2026-10-07, sobre un proyecto **archivado** (la demo pública ya estaba dada de baja). Cada documento está fechado. Las afirmaciones marcadas **FACT** se verificaron ese día (corriendo código, tests o herramientas); las marcadas **INFERENCIA** salen de leer el código sin ejecutarlo — verificalas antes de apoyarte en ellas.

| Si tu tarea toca… | Leé |
|---|---|
| Entender qué es el proyecto, para quién, en qué estado quedó | `PROJECT.md` |
| Árbol de procesos OTP, pipeline web, auth, rate limits, cómo se corrió y se deployó | `ARCHITECTURE.md` |
| Reglas del motor: tipos de nodo, topologías, límites, métricas, modelo de datos | `DOMAIN.md` |
| Escribir código nuevo siguiendo el patrón existente | `CONVENTIONS.md` |
| Entender *por qué* algo se hizo así (y no de la forma obvia) | `DECISIONS.md` |
| Saber qué funciona y qué se verificó vs. qué no, antes de asumir | `CURRENT_STATE.md` |
| Seguridad, bugs confirmados, deuda — **leer antes de re-deployar o exponer públicamente** | `KNOWN_ISSUES.md` |
| Decisiones pendientes que requieren al dueño | `OPEN_QUESTIONS.md` |

## Cómo correrlo (lo único que hace falta saber para empezar)
```bash
docker compose up        # http://localhost:4000 — primera vez tarda unos minutos
docker compose run --rm -e MIX_ENV=test app sh -c "mix deps.get && mix test"
```
Detalle y solución de problemas en `RUN.md` (raíz).

## Regla de este repo
No hay producción: el proyecto está archivado y no corre en ningún servidor. Aun así, **no volver a exponerlo a internet sin resolver antes los ítems 🟠 de `KNOWN_ISSUES.md`** (procesos de invitados que nunca se limpian).

Los archivos `AGENTS.md`, `TASKS.md`, `PORTFOLIO.md`, `MANUAL-PRUEBAS.md`, `commit-plan.*` y `.claude/` son meta de fábrica, están en `.gitignore` y no se publican. Esta carpeta `.ai/` sí es parte del repo.
