defmodule Middleware.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Middleware.Discovery,
      Middleware.Messaging.Supervisor,
      {GRPC.Server.Supervisor,
       endpoint: Middleware.Grpc.Endpoint,
       port: grpc_port(),
       start_server: true},
      {Plug.Cowboy, scheme: :http, plug: Middleware.Router, options: [port: port()]}
    ]

    opts = [strategy: :one_for_one, name: Middleware.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp port do
    "PORT" |> System.get_env("4000") |> String.to_integer()
  end

  defp grpc_port do
    "GRPC_PORT" |> System.get_env("50050") |> String.to_integer()
  end
end
