defmodule ExchangesServiceWeb.Router do
  use Phoenix.Router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ExchangesServiceWeb do
    pipe_through :api

    get "/health", HealthController, :check
  end

  scope "/api", ExchangesServiceWeb do
    pipe_through :api

    get "/exchanges", ExchangeController, :index
    get "/exchanges/:id/stocks", ExchangeController, :stocks
    get "/stocks", StockController, :index
  end
end
