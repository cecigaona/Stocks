defmodule ExchangesService.Catalog.Exchange do
  use Ecto.Schema
  import Ecto.Changeset

  schema "exchanges" do
    field :name, :string
    field :code, :string

    timestamps()
  end

  def changeset(exchange, attrs) do
    exchange
    |> cast(attrs, [:name, :code])
    |> validate_required([:name, :code])
    |> unique_constraint(:code)
  end
end
