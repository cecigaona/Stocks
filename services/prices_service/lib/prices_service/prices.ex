defmodule PricesService.Prices do
  alias PricesService.Repo
  alias PricesService.Prices.StockPrice

  def list_prices do
    Repo.all(StockPrice)
  end

  def get_price(symbol) do
    Repo.get_by(StockPrice, symbol: String.upcase(symbol))
  end

  def fluctuate_all do
    for price <- list_prices() do
      factor = 1 + (:rand.uniform() - 0.5) * 0.02
      new_price = Decimal.mult(price.price, Decimal.from_float(factor)) |> Decimal.round(2)

      new_price =
        if Decimal.compare(new_price, Decimal.new(0)) == :gt, do: new_price, else: price.price

      price
      |> Ecto.Changeset.change(price: new_price)
      |> Repo.update()
    end
  end
end
