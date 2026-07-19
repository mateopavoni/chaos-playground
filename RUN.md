# Cómo levantar chaos-playground

## Requisitos
- Docker + Docker Compose. (No hace falta instalar Elixir/Erlang en el host — corre todo en contenedor.)

## Variables de entorno
- Solo hacen falta para producción/release: copiá `.env.example` a `.env` y completá `SECRET_KEY_BASE`
  (`mix phx.gen.secret`) y `DATABASE_URL`. En desarrollo, `docker-compose.yml` ya trae Postgres configurado.

## Levantar
```bash
docker compose up
```
- Primera vez: instala deps, corre migraciones no incluidas todavía (agregar `mix ecto.setup` cuando
  haya migraciones) y levanta `mix phx.server`.
- App: http://localhost:4000

## Tests
```bash
docker compose run --rm app mix test
```

## Consola interactiva (IEx)
```bash
docker compose run --rm --service-ports app iex -S mix phx.server
```
