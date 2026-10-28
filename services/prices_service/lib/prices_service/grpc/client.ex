defmodule PricesService.Grpc.Client do
  require Logger

  def list_stocks do
    with {:ok, target} <- resolve_target(),
         {:ok, channel} <- GRPC.Stub.connect(target) do
      result = Exchanges.ExchangesService.Stub.list_stocks(channel, %Exchanges.ListStocksRequest{})
      GRPC.Stub.disconnect(channel)
      result
    else
      {:error, reason} ->
        Logger.error("PricesService failed to call ExchangesService gRPC: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def get_stock(symbol) do
    with {:ok, target} <- resolve_target(),
         {:ok, channel} <- GRPC.Stub.connect(target) do
      request = %Exchanges.GetStockRequest{symbol: symbol}
      result = Exchanges.ExchangesService.Stub.get_stock(channel, request)
      GRPC.Stub.disconnect(channel)
      result
    else
      {:error, reason} ->
        Logger.error("PricesService failed to get stock #{symbol} via gRPC: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp resolve_target do
    host = System.get_env("EXCHANGES_GRPC_HOST", "exchanges_service")
    port = System.get_env("EXCHANGES_GRPC_PORT", "50051")
    {:ok, "#{host}:#{port}"}
  end
end
