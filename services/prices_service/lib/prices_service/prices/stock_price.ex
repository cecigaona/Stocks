defmodule PricesService.Prices.StockPrice do
  use Ecto.Schema
  import Ecto.Changeset

  schema "stock_prices" do
    field :symbol, :string
    field :price, :decimal

    timestamps()
  end

  def changeset(stock_price, attrs) do
    stock_price
    |> cast(attrs, [:symbol, :price])
    |> validate_required([:symbol, :price])
    |> unique_constraint(:symbol)
  end
end
