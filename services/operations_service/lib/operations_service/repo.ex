defmodule OperationsService.Repo do
  use Ecto.Repo,
    otp_app: :operations_service,
    adapter: Ecto.Adapters.Postgres
end
