defmodule OperationsServiceWeb.OperationController do
  use Phoenix.Controller, formats: [:json]

  alias OperationsService.Trading

  def index(conn, _params) do
    operations = Trading.list_operations()
    json(conn, %{data: Enum.map(operations, &operation_json/1)})
  end

  def create(conn, params) do
    case Trading.create_operation(params) do
      {:ok, operation} ->
        OperationsService.Messaging.Topic.publish(:operations_events, {:operation_created, %{
          id: operation.id,
          symbol: operation.symbol,
          operation_type: operation.operation_type,
          quantity: operation.quantity,
          price: Decimal.to_string(operation.price),
          total: Decimal.to_string(operation.total)
        }})

        conn
        |> put_status(:created)
        |> json(operation_json(operation))

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: translate_errors(changeset)})
    end
  end

  defp operation_json(op) do
    %{
      id: op.id,
      symbol: op.symbol,
      operation_type: op.operation_type,
      quantity: op.quantity,
      price: op.price,
      total: op.total,
      inserted_at: op.inserted_at
    }
  end

  defp translate_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
