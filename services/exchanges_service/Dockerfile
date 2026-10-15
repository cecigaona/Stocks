FROM elixir:1.17-alpine

RUN apk add --no-cache build-base git bash curl

WORKDIR /app

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs ./
RUN mix deps.get

COPY . .

RUN mix deps.compile

EXPOSE 4001

CMD ["sh", "-c", "mix ecto.create --quiet && mix ecto.migrate && (mix run priv/repo/seeds.exs || true) && mix phx.server"]
