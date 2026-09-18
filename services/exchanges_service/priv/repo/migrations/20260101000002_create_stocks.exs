defmodule ExchangesService.Repo.Migrations.CreateStocks do
  use Ecto.Migration

  def change do
    create table(:stocks) do
      add :symbol, :string, null: false
      add :name, :string, null: false
      add :exchange_id, references(:exchanges, on_delete: :delete_all), null: false

      timestamps()
    end

    create unique_index(:stocks, [:symbol])
    create index(:stocks, [:exchange_id])
  end
end
