ARG ELIXIR_VERSION=1.17
ARG DEBIAN_VERSION=bookworm-slim

FROM elixir:${ELIXIR_VERSION} AS builder

RUN apt-get update -y && apt-get install -y build-essential git curl \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

ENV MIX_ENV=prod

COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

COPY priv priv
COPY lib lib
COPY assets assets

RUN mix compile
RUN mix assets.deploy

COPY config/runtime.exs config/

RUN mix release

FROM debian:${DEBIAN_VERSION}

RUN apt-get update -y \
    && apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR /app
RUN chown nobody /app

ENV MIX_ENV=prod
ENV PHX_SERVER=true

COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/chaos_playground ./

USER nobody

CMD ["/app/bin/chaos_playground", "start"]
