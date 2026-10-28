defmodule Middleware.Grpc.Client do
  require Logger

  @rr_table :middleware_grpc_counters

  def list_exchanges do
    invoke_with_retry("exchanges_service", fn channel ->
      Exchanges.ExchangesService.Stub.list_exchanges(channel, %Exchanges.Empty{})
    end)
  end

  def list_stocks do
    invoke_with_retry("exchanges_service", fn channel ->
      Exchanges.ExchangesService.Stub.list_stocks(channel, %Exchanges.ListStocksRequest{})
    end)
  end

  def list_stocks_by_exchange(exchange_id) do
    invoke_with_retry("exchanges_service", fn channel ->
      req = %Exchanges.ListStocksByExchangeRequest{exchange_id: exchange_id}
      Exchanges.ExchangesService.Stub.list_stocks_by_exchange(channel, req)
    end)
  end

  def get_stock(symbol) do
    invoke_with_retry("exchanges_service", fn channel ->
      req = %Exchanges.GetStockRequest{symbol: symbol}
      Exchanges.ExchangesService.Stub.get_stock(channel, req)
    end)
  end

  def list_prices do
    invoke_with_retry("prices_service", fn channel ->
      Prices.PricesService.Stub.list_prices(channel, %Prices.Empty{})
    end)
  end

  def get_price(symbol) do
    invoke_with_retry("prices_service", fn channel ->
      req = %Prices.GetPriceRequest{symbol: symbol}
      Prices.PricesService.Stub.get_price(channel, req)
    end)
  end

  def fluctuate_prices do
    invoke_with_retry("prices_service", fn channel ->
      Prices.PricesService.Stub.fluctuate_prices(channel, %Prices.Empty{})
    end)
  end

  def list_operations do
    invoke_with_retry("operations_service", fn channel ->
      Operations.OperationsService.Stub.list_operations(channel, %Operations.Empty{})
    end)
  end

  def create_operation(attrs) do
    invoke_with_retry("operations_service", fn channel ->
      req = %Operations.CreateOperationRequest{
        symbol: Map.get(attrs, "symbol", ""),
        operation_type: Map.get(attrs, "operation_type", ""),
        quantity: Map.get(attrs, "quantity", 0),
        price: to_string(Map.get(attrs, "price", "0"))
      }

      Operations.OperationsService.Stub.create_operation(channel, req)
    end)
  end

  def get_portfolio do
    invoke_with_retry("operations_service", fn channel ->
      Operations.OperationsService.Stub.get_portfolio(channel, %Operations.Empty{})
    end)
  end

  defp invoke_with_retry(service_name, rpc_fun) do
    instances = get_ordered_instances(service_name)
    try_instances(instances, rpc_fun, {:error, :no_instances})
  end

  defp try_instances([], _rpc_fun, last_error), do: last_error

  defp try_instances([endpoint | rest], rpc_fun, _last_error) do
    case GRPC.Stub.connect(endpoint) do
      {:ok, channel} ->
        try do
          case rpc_fun.(channel) do
            {:ok, result} ->
              GRPC.Stub.disconnect(channel)
              {:ok, result}

            {:error, %GRPC.RPCError{} = rpc_error} ->
              GRPC.Stub.disconnect(channel)
              {:error, rpc_error}

            {:error, reason} ->
              GRPC.Stub.disconnect(channel)
              Logger.warning("gRPC call failed on #{endpoint}: #{inspect(reason)}, trying next")
              try_instances(rest, rpc_fun, {:error, reason})
          end
        rescue
          e ->
            GRPC.Stub.disconnect(channel)
            Logger.warning("gRPC call exception on #{endpoint}: #{inspect(e)}, trying next")
            try_instances(rest, rpc_fun, {:error, e})
        end

      {:error, reason} ->
        Logger.warning("Failed to connect to #{endpoint}: #{inspect(reason)}, trying next")
        try_instances(rest, rpc_fun, {:error, reason})
    end
  end

  defp get_ordered_instances(service_name) do
    instances = configured_instances(service_name)
    len = length(instances)

    if len <= 1 do
      instances
    else
      ensure_table()
      idx = :ets.update_counter(@rr_table, service_name, {2, 1}, {service_name, 0})
      start = rem(idx, len)
      {left, right} = Enum.split(instances, start)
      right ++ left
    end
  end

  defp configured_instances("exchanges_service") do
    env_instances("EXCHANGES_GRPC_INSTANCES", ["exchanges_service:50051"])
  end

  defp configured_instances("prices_service") do
    env_instances("PRICES_GRPC_INSTANCES", ["prices_service:50052"])
  end

  defp configured_instances("operations_service") do
    env_instances("OPERATIONS_GRPC_INSTANCES", ["operations_service:50053"])
  end

  defp env_instances(env_var, default_list) do
    case System.get_env(env_var) do
      nil -> default_list
      "" -> default_list
      val -> String.split(val, ",", trim: true)
    end
  end

  defp ensure_table do
    if :ets.info(@rr_table) == :undefined do
      :ets.new(@rr_table, [:named_table, :public, :set, write_concurrency: true])
    end
  rescue
    _ -> :ok
  end
end
