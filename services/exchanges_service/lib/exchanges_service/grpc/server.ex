defmodule ExchangesService.Grpc.Server do
  use GRPC.Server, service: Exchanges.ExchangesService.Service

  alias ExchangesService.Catalog
  alias ExchangesService.Repo
  alias ExchangesService.Catalog.Stock
  alias ExchangesService.Messaging.Topic

  def list_exchanges(%Exchanges.Empty{}, _stream) do
    exchanges =
      Catalog.list_exchanges()
      |> Enum.map(fn exchange ->
        %Exchanges.Exchange{
          id: exchange.id,
          name: exchange.name,
          code: exchange.code
        }
      end)

    %Exchanges.ListExchangesResponse{exchanges: exchanges}
  end

  def list_stocks(%Exchanges.ListStocksRequest{}, _stream) do
    stocks =
      Catalog.list_stocks()
      |> Enum.map(&to_stock_proto/1)

    %Exchanges.ListStocksResponse{stocks: stocks}
  end

  def list_stocks_by_exchange(%Exchanges.ListStocksByExchangeRequest{exchange_id: id}, _stream) do
    stocks =
      Catalog.list_stocks_by_exchange(id)
      |> Enum.map(&to_stock_proto/1)

    %Exchanges.ListStocksResponse{stocks: stocks}
  end

  def get_stock(%Exchanges.GetStockRequest{symbol: symbol}, _stream) do
    normalized_symbol = symbol |> to_string() |> String.trim() |> String.upcase()

    case Repo.get_by(Stock, symbol: normalized_symbol) do
      nil ->
        raise GRPC.RPCError, status: :not_found, message: "Stock #{symbol} not found"

      stock ->
        Topic.publish(:exchanges_events, {:stock_queried, %{symbol: stock.symbol, id: stock.id}})
        %Exchanges.StockResponse{stock: to_stock_proto(stock)}
    end
  end

  defp to_stock_proto(stock) do
    %Exchanges.Stock{
      id: stock.id,
      symbol: stock.symbol,
      name: stock.name,
      exchange_id: stock.exchange_id
    }
  end
end
