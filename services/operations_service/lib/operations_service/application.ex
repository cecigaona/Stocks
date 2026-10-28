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
        OperationsServiceWeb.Endpoint,
        OperationsService.Messaging.Supervisor,
        {GRPC.Server.Supervisor,
         endpoint: OperationsService.Grpc.Endpoint,
         port: grpc_port(),
         start_server: true}
      ] ++ consul_children

    opts = [strategy: :one_for_one, name: OperationsService.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp grpc_port do
    "GRPC_PORT"
    |> System.get_env("50053")
    |> String.to_integer()
  end

  @impl true
  def config_change(changed, _new, removed) do
    OperationsServiceWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
