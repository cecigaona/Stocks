defmodule PricesService.Repo.Migrations.CreateStockPrices do
  use Ecto.Migration

  def change do
    create table(:stock_prices) do
      add :symbol, :string, null: false
      add :price, :decimal, precision: 12, scale: 2, null: false

      timestamps()
    end

    create unique_index(:stock_prices, [:symbol])
  end
end
