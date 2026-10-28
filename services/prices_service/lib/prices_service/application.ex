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
        PricesService.Simulator,
        PricesService.Messaging.Supervisor,
        {GRPC.Server.Supervisor,
         endpoint: PricesService.Grpc.Endpoint,
         port: grpc_port(),
         start_server: true}
      ] ++ consul_children

    opts = [strategy: :one_for_one, name: PricesService.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp grpc_port do
    "GRPC_PORT"
    |> System.get_env("50052")
    |> String.to_integer()
  end

  @impl true
  def config_change(changed, _new, removed) do
    PricesServiceWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
