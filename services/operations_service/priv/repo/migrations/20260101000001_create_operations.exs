defmodule OperationsService.Repo.Migrations.CreateOperations do
  use Ecto.Migration

  def change do
    create table(:operations) do
      add :symbol, :string, null: false
      add :operation_type, :string, null: false
      add :quantity, :integer, null: false
      add :price, :decimal, precision: 12, scale: 2, null: false
      add :total, :decimal, precision: 14, scale: 2, null: false

      timestamps()
    end

    create index(:operations, [:symbol])
  end
end
