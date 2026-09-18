defmodule ExchangesService.Repo do
  use Ecto.Repo,
    otp_app: :exchanges_service,
    adapter: Ecto.Adapters.Postgres
end
