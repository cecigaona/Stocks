defmodule PricesService.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      PricesService.Repo,
      PricesServiceWeb.Endpoint,
      PricesService.Simulator
    ]

    opts = [strategy: :one_for_one, name: PricesService.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    PricesServiceWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
