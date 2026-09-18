defmodule ExchangesService.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ExchangesService.Repo,
      ExchangesServiceWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: ExchangesService.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    ExchangesServiceWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
