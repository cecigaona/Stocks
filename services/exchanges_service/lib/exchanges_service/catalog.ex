defmodule ExchangesService.Catalog do
  import Ecto.Query

  alias ExchangesService.Repo
  alias ExchangesService.Catalog.{Exchange, Stock}

  def list_exchanges do
    Repo.all(Exchange)
  end

  def list_stocks do
    Repo.all(Stock)
  end

  def list_stocks_by_exchange(exchange_id) do
    Stock
    |> where([s], s.exchange_id == ^exchange_id)
    |> Repo.all()
  end
end
