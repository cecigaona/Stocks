defmodule ExchangesService.Repo.Migrations.CreateExchanges do
  use Ecto.Migration

  def change do
    create table(:exchanges) do
      add :name, :string, null: false
      add :code, :string, null: false

      timestamps()
    end

    create unique_index(:exchanges, [:code])
  end
end
