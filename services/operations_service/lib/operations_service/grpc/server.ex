defmodule OperationsService.Grpc.Server do
  use GRPC.Server, service: Operations.OperationsService.Service

  alias OperationsService.Trading
  alias OperationsService.Grpc.Client, as: InterServiceClient
  alias OperationsService.Messaging.Topic

  def list_operations(%Operations.Empty{}, _stream) do
    operations =
      Trading.list_operations()
      |> Enum.map(&to_operation_proto/1)

    %Operations.ListOperationsResponse{operations: operations}
  end

  def create_operation(%Operations.CreateOperationRequest{} = req, _stream) do
    symbol = req.symbol |> to_string() |> String.trim() |> String.upcase()

    case InterServiceClient.get_stock(symbol) do
      {:ok, _stock_response} ->
        price_to_use = resolve_price(symbol, req.price)

        attrs = %{
          "symbol" => symbol,
          "operation_type" => req.operation_type,
          "quantity" => req.quantity,
          "price" => price_to_use
        }

        case Trading.create_operation(attrs) do
          {:ok, operation} ->
            Topic.publish(:operations_events, {:operation_created, %{
              id: operation.id,
              symbol: operation.symbol,
              operation_type: operation.operation_type,
              quantity: operation.quantity,
              price: Decimal.to_string(operation.price),
              total: Decimal.to_string(operation.total)
            }})

            %Operations.OperationResponse{operation: to_operation_proto(operation)}

          {:error, changeset} ->
            error_message = inspect(changeset.errors)
            raise GRPC.RPCError, status: :invalid_argument, message: error_message
        end

      {:error, _reason} ->
        raise GRPC.RPCError, status: :not_found, message: "Stock #{symbol} does not exist in catalog"
    end
  end

  def get_portfolio(%Operations.Empty{}, _stream) do
    items =
      Trading.portfolio()
      |> Enum.map(fn item ->
        %Operations.PortfolioItem{
          symbol: item.symbol,
          quantity: item.quantity,
          net_invested: Decimal.to_string(item.net_invested)
        }
      end)

    %Operations.PortfolioResponse{items: items}
  end

  defp resolve_price(_symbol, price) when is_binary(price) and byte_size(price) > 0 and price != "0" do
    price
  end

  defp resolve_price(symbol, _price) do
    case InterServiceClient.get_price(symbol) do
      {:ok, %Prices.PriceResponse{price: %Prices.StockPrice{price: fetched_price}}} ->
        fetched_price

      _ ->
        "100.00"
    end
  end

  defp to_operation_proto(op) do
    inserted_at_str =
      case op.inserted_at do
        nil -> ""
        %DateTime{} = dt -> DateTime.to_iso8601(dt)
        %NaiveDateTime{} = ndt -> NaiveDateTime.to_iso8601(ndt)
        val -> to_string(val)
      end

    %Operations.Operation{
      id: op.id,
      symbol: op.symbol,
      operation_type: op.operation_type,
      quantity: op.quantity,
      price: Decimal.to_string(op.price),
      total: Decimal.to_string(op.total),
      inserted_at: inserted_at_str
    }
  end
end
