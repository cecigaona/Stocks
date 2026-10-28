defmodule Operations.Empty do
  use Protobuf,
    full_name: "operations.Empty",
    protoc_gen_elixir_version: "0.17.1",
    syntax: :proto3
end

defmodule Operations.Operation do
  use Protobuf,
    full_name: "operations.Operation",
    protoc_gen_elixir_version: "0.17.1",
    syntax: :proto3

  field :id, 1, type: :int64
  field :symbol, 2, type: :string
  field :operation_type, 3, type: :string, json_name: "operationType"
  field :quantity, 4, type: :int32
  field :price, 5, type: :string
  field :total, 6, type: :string
  field :inserted_at, 7, type: :string, json_name: "insertedAt"
end

defmodule Operations.PortfolioItem do
  use Protobuf,
    full_name: "operations.PortfolioItem",
    protoc_gen_elixir_version: "0.17.1",
    syntax: :proto3

  field :symbol, 1, type: :string
  field :quantity, 2, type: :int32
  field :net_invested, 3, type: :string, json_name: "netInvested"
end

defmodule Operations.ListOperationsResponse do
  use Protobuf,
    full_name: "operations.ListOperationsResponse",
    protoc_gen_elixir_version: "0.17.1",
    syntax: :proto3

  field :operations, 1, repeated: true, type: Operations.Operation
end

defmodule Operations.CreateOperationRequest do
  use Protobuf,
    full_name: "operations.CreateOperationRequest",
    protoc_gen_elixir_version: "0.17.1",
    syntax: :proto3

  field :symbol, 1, type: :string
  field :operation_type, 2, type: :string, json_name: "operationType"
  field :quantity, 3, type: :int32
  field :price, 4, type: :string
end

defmodule Operations.OperationResponse do
  use Protobuf,
    full_name: "operations.OperationResponse",
    protoc_gen_elixir_version: "0.17.1",
    syntax: :proto3

  field :operation, 1, type: Operations.Operation
end

defmodule Operations.PortfolioResponse do
  use Protobuf,
    full_name: "operations.PortfolioResponse",
    protoc_gen_elixir_version: "0.17.1",
    syntax: :proto3

  field :items, 1, repeated: true, type: Operations.PortfolioItem
end

defmodule Operations.OperationsService.Service do
  use GRPC.Service, name: "operations.OperationsService", protoc_gen_elixir_version: "0.17.1"

  rpc :ListOperations, Operations.Empty, Operations.ListOperationsResponse
  rpc :CreateOperation, Operations.CreateOperationRequest, Operations.OperationResponse
  rpc :GetPortfolio, Operations.Empty, Operations.PortfolioResponse
end

defmodule Operations.OperationsService.Stub do
  use GRPC.Stub, service: Operations.OperationsService.Service
end
