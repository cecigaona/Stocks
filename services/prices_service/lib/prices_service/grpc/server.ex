defmodule PricesService.Grpc.Server do
  use GRPC.Server, service: Prices.PricesService.Service

  alias PricesService.Prices, as: DomainPrices
  alias PricesService.Messaging.Topic

  def list_prices(%Prices.Empty{}, _stream) do
    prices =
      DomainPrices.list_prices()
      |> Enum.map(&to_price_proto/1)

    %Prices.ListPricesResponse{prices: prices}
  end

  def get_price(%Prices.GetPriceRequest{symbol: symbol}, _stream) do
    case DomainPrices.get_price(symbol) do
      nil ->
        raise GRPC.RPCError, status: :not_found, message: "Price for #{symbol} not found"

      price ->
        %Prices.PriceResponse{price: to_price_proto(price)}
    end
  end

  def fluctuate_prices(%Prices.Empty{}, _stream) do
    results = DomainPrices.fluctuate_all()
    count = length(results)

    Topic.publish(:prices_events, {:batch_fluctuated, %{updated_count: count}})

    %Prices.FluctuatePricesResponse{updated_count: count}
  end

  defp to_price_proto(price) do
    updated_at_str =
      case price.updated_at do
        nil -> ""
        %DateTime{} = dt -> DateTime.to_iso8601(dt)
        %NaiveDateTime{} = ndt -> NaiveDateTime.to_iso8601(ndt)
        val -> to_string(val)
      end

    %Prices.StockPrice{
      id: price.id,
      symbol: price.symbol,
      price: Decimal.to_string(price.price),
      updated_at: updated_at_str
    }
  end
end
