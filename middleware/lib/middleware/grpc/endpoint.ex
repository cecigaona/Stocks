defmodule Middleware.Grpc.Endpoint do
  use GRPC.Endpoint

  intercept GRPC.Server.Interceptors.Logger
  run Middleware.Grpc.ExchangesServer
  run Middleware.Grpc.PricesServer
  run Middleware.Grpc.OperationsServer
end
