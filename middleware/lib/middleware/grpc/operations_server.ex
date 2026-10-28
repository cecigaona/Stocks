defmodule Middleware.Grpc.OperationsServer do
  use GRPC.Server, service: Operations.OperationsService.Service

  alias Middleware.Grpc.Client

  def list_operations(%Operations.Empty{}, _stream) do
    case Client.list_operations() do
      {:ok, resp} -> resp
      {:error, reason} -> raise GRPC.RPCError, status: :unavailable, message: inspect(reason)
    end
  end

  def create_operation(%Operations.CreateOperationRequest{} = req, _stream) do
    attrs = %{
      "symbol" => req.symbol,
      "operation_type" => req.operation_type,
      "quantity" => req.quantity,
      "price" => req.price
    }

    case Client.create_operation(attrs) do
      {:ok, resp} -> resp
      {:error, %GRPC.RPCError{} = err} -> raise err
      {:error, reason} -> raise GRPC.RPCError, status: :unavailable, message: inspect(reason)
    end
  end

  def get_portfolio(%Operations.Empty{}, _stream) do
    case Client.get_portfolio() do
      {:ok, resp} -> resp
      {:error, reason} -> raise GRPC.RPCError, status: :unavailable, message: inspect(reason)
    end
  end
end
