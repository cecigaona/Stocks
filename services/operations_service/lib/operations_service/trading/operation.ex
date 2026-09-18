defmodule OperationsService.Trading.Operation do
  use Ecto.Schema
  import Ecto.Changeset

  schema "operations" do
    field :symbol, :string
    field :operation_type, :string
    field :quantity, :integer
    field :price, :decimal
    field :total, :decimal

    timestamps()
  end

  def changeset(operation, attrs) do
    operation
    |> cast(attrs, [:symbol, :operation_type, :quantity, :price, :total])
    |> validate_required([:symbol, :operation_type, :quantity, :price, :total])
    |> validate_inclusion(:operation_type, ["buy", "sell"])
    |> validate_number(:quantity, greater_than: 0)
    |> validate_number(:price, greater_than: 0)
  end
end
