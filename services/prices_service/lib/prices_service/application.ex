defmodule PricesService.Application do
  use Application

  @impl true
  def start(_type, _args) do
    consul_config = Application.get_env(:prices_service, :consul, [])

    consul_children =
      if Keyword.get(consul_config, :enabled, true) do
        [
          PricesService.Consul.Discovery,
          PricesService.Consul.Registrar
        ]
      else
        []
      end

    children =
      [
        PricesService.Repo,
        PricesServiceWeb.Endpoint,
        PricesService.Simulator
      ] ++ consul_children

    opts = [strategy: :one_for_one, name: PricesService.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    PricesServiceWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
