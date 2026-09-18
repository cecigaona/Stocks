defmodule OperationsServiceWeb.Router do
  use Phoenix.Router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", OperationsServiceWeb do
    pipe_through :api

    get "/operations", OperationController, :index
    post "/operations", OperationController, :create
    get "/portfolio", PortfolioController, :index
  end
end
