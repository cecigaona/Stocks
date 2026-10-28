defmodule Middleware.Grpc.ExchangesServer do
  use GRPC.Server, service: Exchanges.ExchangesService.Service

  alias Middleware.Grpc.Client

  def list_exchanges(%Exchanges.Empty{}, _stream) do
    case Client.list_exchanges() do
      {:ok, resp} -> resp
      {:error, reason} -> raise GRPC.RPCError, status: :unavailable, message: inspect(reason)
    end
  end

  def list_stocks(%Exchanges.ListStocksRequest{}, _stream) do
    case Client.list_stocks() do
      {:ok, resp} -> resp
      {:error, reason} -> raise GRPC.RPCError, status: :unavailable, message: inspect(reason)
    end
  end

  def list_stocks_by_exchange(%Exchanges.ListStocksByExchangeRequest{exchange_id: id}, _stream) do
    case Client.list_stocks_by_exchange(id) do
      {:ok, resp} -> resp
      {:error, reason} -> raise GRPC.RPCError, status: :unavailable, message: inspect(reason)
    end
  end

  def get_stock(%Exchanges.GetStockRequest{symbol: symbol}, _stream) do
    case Client.get_stock(symbol) do
      {:ok, resp} -> resp
      {:error, %GRPC.RPCError{} = err} -> raise err
      {:error, reason} -> raise GRPC.RPCError, status: :unavailable, message: inspect(reason)
    end
  end
end
