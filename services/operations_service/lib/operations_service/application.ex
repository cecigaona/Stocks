defmodule OperationsService.Application do
  use Application

  @impl true
  def start(_type, _args) do
    consul_config = Application.get_env(:operations_service, :consul, [])

    consul_children =
      if Keyword.get(consul_config, :enabled, true) do
        [
          OperationsService.Consul.Discovery,
          OperationsService.Consul.Registrar
        ]
      else
        []
      end

    children =
      [
        OperationsService.Repo,
        OperationsServiceWeb.Endpoint
      ] ++ consul_children

    opts = [strategy: :one_for_one, name: OperationsService.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    OperationsServiceWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
