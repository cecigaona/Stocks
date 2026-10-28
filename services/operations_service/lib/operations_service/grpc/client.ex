defmodule OperationsService.Grpc.Client do
  require Logger

  def get_stock(symbol) do
    with {:ok, target} <- resolve_target(:exchanges),
         {:ok, channel} <- GRPC.Stub.connect(target) do
      request = %Exchanges.GetStockRequest{symbol: symbol}
      result = Exchanges.ExchangesService.Stub.get_stock(channel, request)
      GRPC.Stub.disconnect(channel)
      result
    else
      {:error, reason} ->
        Logger.error("OperationsService failed to get stock #{symbol} via gRPC: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def get_price(symbol) do
    with {:ok, target} <- resolve_target(:prices),
         {:ok, channel} <- GRPC.Stub.connect(target) do
      request = %Prices.GetPriceRequest{symbol: symbol}
      result = Prices.PricesService.Stub.get_price(channel, request)
      GRPC.Stub.disconnect(channel)
      result
    else
      {:error, reason} ->
        Logger.error("OperationsService failed to get price for #{symbol} via gRPC: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp resolve_target(:exchanges) do
    host = System.get_env("EXCHANGES_GRPC_HOST", "exchanges_service")
    port = System.get_env("EXCHANGES_GRPC_PORT", "50051")
    {:ok, "#{host}:#{port}"}
  end

  defp resolve_target(:prices) do
    host = System.get_env("PRICES_GRPC_HOST", "prices_service")
    port = System.get_env("PRICES_GRPC_PORT", "50052")
    {:ok, "#{host}:#{port}"}
  end
end
