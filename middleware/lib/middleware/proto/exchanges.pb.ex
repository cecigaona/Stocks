defmodule Exchanges.Empty do
  use Protobuf, full_name: "exchanges.Empty", protoc_gen_elixir_version: "0.17.1", syntax: :proto3
end

defmodule Exchanges.Exchange do
  use Protobuf,
    full_name: "exchanges.Exchange",
    protoc_gen_elixir_version: "0.17.1",
    syntax: :proto3

  field :id, 1, type: :int64
  field :name, 2, type: :string
  field :code, 3, type: :string
end

defmodule Exchanges.Stock do
  use Protobuf, full_name: "exchanges.Stock", protoc_gen_elixir_version: "0.17.1", syntax: :proto3

  field :id, 1, type: :int64
  field :symbol, 2, type: :string
  field :name, 3, type: :string
  field :exchange_id, 4, type: :int64, json_name: "exchangeId"
end

defmodule Exchanges.ListExchangesResponse do
  use Protobuf,
    full_name: "exchanges.ListExchangesResponse",
    protoc_gen_elixir_version: "0.17.1",
    syntax: :proto3

  field :exchanges, 1, repeated: true, type: Exchanges.Exchange
end

defmodule Exchanges.ListStocksRequest do
  use Protobuf,
    full_name: "exchanges.ListStocksRequest",
    protoc_gen_elixir_version: "0.17.1",
    syntax: :proto3
end

defmodule Exchanges.ListStocksResponse do
  use Protobuf,
    full_name: "exchanges.ListStocksResponse",
    protoc_gen_elixir_version: "0.17.1",
    syntax: :proto3

  field :stocks, 1, repeated: true, type: Exchanges.Stock
end

defmodule Exchanges.ListStocksByExchangeRequest do
  use Protobuf,
    full_name: "exchanges.ListStocksByExchangeRequest",
    protoc_gen_elixir_version: "0.17.1",
    syntax: :proto3

  field :exchange_id, 1, type: :int64, json_name: "exchangeId"
end

defmodule Exchanges.GetStockRequest do
  use Protobuf,
    full_name: "exchanges.GetStockRequest",
    protoc_gen_elixir_version: "0.17.1",
    syntax: :proto3

  field :symbol, 1, type: :string
end

defmodule Exchanges.StockResponse do
  use Protobuf,
    full_name: "exchanges.StockResponse",
    protoc_gen_elixir_version: "0.17.1",
    syntax: :proto3

  field :stock, 1, type: Exchanges.Stock
end

defmodule Exchanges.ExchangesService.Service do
  use GRPC.Service, name: "exchanges.ExchangesService", protoc_gen_elixir_version: "0.17.1"

  rpc :ListExchanges, Exchanges.Empty, Exchanges.ListExchangesResponse
  rpc :ListStocks, Exchanges.ListStocksRequest, Exchanges.ListStocksResponse
  rpc :ListStocksByExchange, Exchanges.ListStocksByExchangeRequest, Exchanges.ListStocksResponse
  rpc :GetStock, Exchanges.GetStockRequest, Exchanges.StockResponse
end

defmodule Exchanges.ExchangesService.Stub do
  use GRPC.Stub, service: Exchanges.ExchangesService.Service
end
