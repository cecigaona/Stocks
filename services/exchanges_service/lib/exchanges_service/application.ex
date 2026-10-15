defmodule ExchangesService.Application do
  use Application

  @impl true
  def start(_type, _args) do
    consul_config = Application.get_env(:exchanges_service, :consul, [])

    consul_children =
      if Keyword.get(consul_config, :enabled, true) do
        [
          ExchangesService.Consul.Discovery,
          ExchangesService.Consul.Registrar
        ]
      else
        []
      end

    children =
      [
        ExchangesService.Repo,
        ExchangesServiceWeb.Endpoint
      ] ++ consul_children

    opts = [strategy: :one_for_one, name: ExchangesService.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    ExchangesServiceWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
