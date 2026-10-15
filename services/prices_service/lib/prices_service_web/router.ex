defmodule PricesServiceWeb.Router do
  use Phoenix.Router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", PricesServiceWeb do
    pipe_through :api

    get "/health", HealthController, :check
  end

  scope "/api", PricesServiceWeb do
    pipe_through :api

    get "/prices", PriceController, :index
    get "/prices/:symbol", PriceController, :show
  end
end
