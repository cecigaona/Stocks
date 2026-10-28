FROM elixir:1.17-alpine

RUN apk add --no-cache build-base git bash curl

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

ENV HEX_HTTP_TIMEOUT=120

COPY mix.exs mix.lock* ./
RUN mix deps.get

COPY . .

RUN mix deps.compile

EXPOSE 4000 50050

CMD ["mix", "run", "--no-halt"]
