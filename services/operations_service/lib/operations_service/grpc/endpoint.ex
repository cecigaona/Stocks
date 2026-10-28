defmodule OperationsService.Grpc.Endpoint do
  use GRPC.Endpoint

  intercept GRPC.Server.Interceptors.Logger
  run OperationsService.Grpc.Server
end
