defmodule PricesService.Repo do
  use Ecto.Repo,
    otp_app: :prices_service,
    adapter: Ecto.Adapters.Postgres
end
