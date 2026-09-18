defmodule OperationsService.Trading do
  import Ecto.Query

  alias OperationsService.Repo
  alias OperationsService.Trading.Operation

  def list_operations do
    Operation
    |> order_by([o], desc: o.inserted_at)
    |> Repo.all()
  end

  def create_operation(attrs) do
    attrs
    |> add_total()
    |> then(fn attrs -> %Operation{} |> Operation.changeset(attrs) |> Repo.insert() end)
  end

  def portfolio do
    list_operations()
    |> Enum.group_by(& &1.symbol)
    |> Enum.map(fn {symbol, ops} -> summarize(symbol, ops) end)
    |> Enum.sort_by(& &1.symbol)
  end

  defp summarize(symbol, ops) do
    {quantity, net_invested} =
      Enum.reduce(ops, {0, Decimal.new(0)}, fn op, {qty_acc, invested_acc} ->
        case op.operation_type do
          "buy" -> {qty_acc + op.quantity, Decimal.add(invested_acc, op.total)}
          "sell" -> {qty_acc - op.quantity, Decimal.sub(invested_acc, op.total)}
        end
      end)

    %{symbol: symbol, quantity: quantity, net_invested: net_invested}
  end

  defp add_total(%{"quantity" => quantity, "price" => price} = attrs) do
    total = Decimal.mult(to_decimal(quantity), to_decimal(price))
    Map.put(attrs, "total", total)
  end

  defp add_total(attrs), do: attrs

  defp to_decimal(%Decimal{} = value), do: value
  defp to_decimal(value) when is_integer(value), do: Decimal.new(value)
  defp to_decimal(value) when is_float(value), do: Decimal.from_float(value)
  defp to_decimal(value) when is_binary(value), do: Decimal.new(value)
end
