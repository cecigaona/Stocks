defmodule ExchangesService.Grpc.Endpoint do
  use GRPC.Endpoint

  intercept GRPC.Server.Interceptors.Logger
  run ExchangesService.Grpc.Server
end
