defmodule Middleware.Grpc.PricesServer do
  use GRPC.Server, service: Prices.PricesService.Service

  alias Middleware.Grpc.Client

  def list_prices(%Prices.Empty{}, _stream) do
    case Client.list_prices() do
      {:ok, resp} -> resp
      {:error, reason} -> raise GRPC.RPCError, status: :unavailable, message: inspect(reason)
    end
  end

  def get_price(%Prices.GetPriceRequest{symbol: symbol}, _stream) do
    case Client.get_price(symbol) do
      {:ok, resp} -> resp
      {:error, %GRPC.RPCError{} = err} -> raise err
      {:error, reason} -> raise GRPC.RPCError, status: :unavailable, message: inspect(reason)
    end
  end

  def fluctuate_prices(%Prices.Empty{}, _stream) do
    case Client.fluctuate_prices() do
      {:ok, resp} -> resp
      {:error, reason} -> raise GRPC.RPCError, status: :unavailable, message: inspect(reason)
    end
  end
end
