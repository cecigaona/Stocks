alias PricesService.Repo
alias PricesService.Prices.StockPrice

if Repo.aggregate(StockPrice, :count, :id) == 0 do
  seed_prices = [
    {"AAPL", "227.50"},
    {"MSFT", "415.20"},
    {"GOOGL", "168.30"},
    {"KO", "63.10"},
    {"JPM", "210.45"},
    {"WMT", "78.90"},
    {"AMXL", "16.75"},
    {"GFNORTEO", "145.60"}
  ]

  for {symbol, price} <- seed_prices do
    Repo.insert!(%StockPrice{symbol: symbol, price: Decimal.new(price)})
  end
end
