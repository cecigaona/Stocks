defmodule OperationsService.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      OperationsService.Repo,
      OperationsServiceWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: OperationsService.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def config_change(changed, _new, removed) do
    OperationsServiceWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
