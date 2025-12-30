FROM elixir:1.18-otp-27 AS builder

RUN apt-get update && apt-get install -y nodejs npm && rm -rf /var/lib/apt/lists/*

WORKDIR /app

COPY mix.exs mix.lock ./
RUN mix local.hex --force && mix local.rebar --force && mix deps.get --only prod

COPY priv/playwright/package*.json ./priv/playwright/
RUN cd priv/playwright && npm ci

COPY . .

RUN cd priv/playwright && npm run build
RUN MIX_ENV=prod mix release

# Runtime - imagen sin Elixir (solo Erlang runtime incluido en release)
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    libstdc++6 openssl libncurses6 locales \
    nodejs npm curl \
    && rm -rf /var/lib/apt/lists/* \
    && sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

WORKDIR /app

COPY --from=builder /app/_build/prod/rel/consulta_pex ./
COPY --from=builder /app/priv/playwright ./priv/playwright

RUN cd priv/playwright && npx playwright install firefox --with-deps

EXPOSE 4000

CMD ["bin/consulta_pex", "start"]
