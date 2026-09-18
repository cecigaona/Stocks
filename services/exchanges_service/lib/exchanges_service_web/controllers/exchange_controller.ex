defmodule ExchangesServiceWeb.ExchangeController do
  use Phoenix.Controller, formats: [:json]

  alias ExchangesService.Catalog

  def index(conn, _params) do
    exchanges = Catalog.list_exchanges()
    json(conn, %{data: Enum.map(exchanges, &exchange_json/1)})
  end

  def stocks(conn, %{"id" => id}) do
    stocks = Catalog.list_stocks_by_exchange(id)
    json(conn, %{data: Enum.map(stocks, &stock_json/1)})
  end

  defp exchange_json(e) do
    %{id: e.id, name: e.name, code: e.code}
  end

  defp stock_json(s) do
    %{id: s.id, symbol: s.symbol, name: s.name, exchange_id: s.exchange_id}
  end
end
