alias OperationsService.Repo
alias OperationsService.Trading.Operation

if Repo.aggregate(Operation, :count, :id) == 0 do
  Repo.insert!(%Operation{
    symbol: "AAPL",
    operation_type: "buy",
    quantity: 10,
    price: Decimal.new("227.50"),
    total: Decimal.new("2275.00")
  })

  Repo.insert!(%Operation{
    symbol: "MSFT",
    operation_type: "buy",
    quantity: 5,
    price: Decimal.new("415.20"),
    total: Decimal.new("2076.00")
  })
end
