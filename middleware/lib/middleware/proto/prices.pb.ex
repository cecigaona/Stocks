defmodule Prices.Empty do
  use Protobuf, full_name: "prices.Empty", protoc_gen_elixir_version: "0.17.1", syntax: :proto3
end

defmodule Prices.StockPrice do
  use Protobuf,
    full_name: "prices.StockPrice",
    protoc_gen_elixir_version: "0.17.1",
    syntax: :proto3

  field :id, 1, type: :int64
  field :symbol, 2, type: :string
  field :price, 3, type: :string
  field :updated_at, 4, type: :string, json_name: "updatedAt"
end

defmodule Prices.ListPricesResponse do
  use Protobuf,
    full_name: "prices.ListPricesResponse",
    protoc_gen_elixir_version: "0.17.1",
    syntax: :proto3

  field :prices, 1, repeated: true, type: Prices.StockPrice
end

defmodule Prices.GetPriceRequest do
  use Protobuf,
    full_name: "prices.GetPriceRequest",
    protoc_gen_elixir_version: "0.17.1",
    syntax: :proto3

  field :symbol, 1, type: :string
end

defmodule Prices.PriceResponse do
  use Protobuf,
    full_name: "prices.PriceResponse",
    protoc_gen_elixir_version: "0.17.1",
    syntax: :proto3

  field :price, 1, type: Prices.StockPrice
end

defmodule Prices.FluctuatePricesResponse do
  use Protobuf,
    full_name: "prices.FluctuatePricesResponse",
    protoc_gen_elixir_version: "0.17.1",
    syntax: :proto3

  field :updated_count, 1, type: :int32, json_name: "updatedCount"
end

defmodule Prices.PricesService.Service do
  use GRPC.Service, name: "prices.PricesService", protoc_gen_elixir_version: "0.17.1"

  rpc :ListPrices, Prices.Empty, Prices.ListPricesResponse
  rpc :GetPrice, Prices.GetPriceRequest, Prices.PriceResponse
  rpc :FluctuatePrices, Prices.Empty, Prices.FluctuatePricesResponse
end

defmodule Prices.PricesService.Stub do
  use GRPC.Stub, service: Prices.PricesService.Service
end
