defmodule ExchangesService.Catalog.Stock do
  use Ecto.Schema
  import Ecto.Changeset

  schema "stocks" do
    field :symbol, :string
    field :name, :string
    belongs_to :exchange, ExchangesService.Catalog.Exchange

    timestamps()
  end

  def changeset(stock, attrs) do
    stock
    |> cast(attrs, [:symbol, :name, :exchange_id])
    |> validate_required([:symbol, :name, :exchange_id])
    |> unique_constraint(:symbol)
    |> foreign_key_constraint(:exchange_id)
  end
end
