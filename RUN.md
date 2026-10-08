# Cómo levantar chaos-playground

## Requisitos
- Docker + Docker Compose v2. No hace falta Elixir/Erlang/Node en el host: todo corre en contenedor.
- Puerto `4000` libre en el host (o `APP_PORT=4010 docker compose up` para usar otro).
- Internet la primera vez: se bajan las dependencias de Hex y los binarios de tailwind/esbuild.

## Levantar
```bash
docker compose up
```
Abrir http://localhost:4000. La primera vez tarda unos minutos; después arranca en segundos.

En cada arranque el contenedor `app` corre, en orden: `mix deps.get`, `mix assets.setup`,
`mix ecto.setup` (crea la DB, migra y corre seeds — idempotente) y `mix phx.server`.
La DB (`db`, Postgres 16) no publica puertos al host: solo la app la alcanza, por la red interna de compose.

Healthcheck: `docker compose ps` muestra `healthy` cuando la app ya responde.

## Variables
Para desarrollo local no hace falta ninguna. `.env.example` documenta las de un release de producción
(`DATABASE_URL`, `SECRET_KEY_BASE`, `PHX_HOST`, `PORT`) y solo aplica si construís la imagen del `Dockerfile`.

## Tests
```bash
docker compose run --rm -e MIX_ENV=test app sh -c "mix deps.get && mix test"
```
Crea y migra la DB `chaos_playground_test` por su cuenta.

## Consola interactiva (IEx)
```bash
docker compose run --rm --service-ports app iex -S mix phx.server
```

## Resetear todo
```bash
docker compose down -v   # borra también la base de datos
```

## Solución de problemas
- **`address already in use` en el 4000**: algo en tu host ya lo usa; levantá con `APP_PORT=4010`.
- **Los archivos de `deps/`, `_build/` o `.home/` quedaron con otro dueño**: el contenedor corre con
  UID:GID 1000:1000 por defecto. Si el tuyo es otro: `HOST_UID=$(id -u) HOST_GID=$(id -g) docker compose up`.
- **El navegador no recarga solo al editar archivos**: la imagen `elixir:1.17` no trae `inotify-tools`, así
  que el live-reload del navegador no funciona dentro del contenedor. El código sí se recompila al
  recargar la página a mano.
