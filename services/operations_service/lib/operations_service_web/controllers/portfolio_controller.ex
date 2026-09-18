defmodule OperationsServiceWeb.PortfolioController do
  use Phoenix.Controller, formats: [:json]

  alias OperationsService.Trading

  def index(conn, _params) do
    json(conn, %{data: Trading.portfolio()})
  end
end
