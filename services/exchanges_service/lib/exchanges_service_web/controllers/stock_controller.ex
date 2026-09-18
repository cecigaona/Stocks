defmodule ExchangesServiceWeb.StockController do
  use Phoenix.Controller, formats: [:json]

  alias ExchangesService.Catalog

  def index(conn, _params) do
    stocks = Catalog.list_stocks()
    json(conn, %{data: Enum.map(stocks, &stock_json/1)})
  end

  defp stock_json(s) do
    %{id: s.id, symbol: s.symbol, name: s.name, exchange_id: s.exchange_id}
  end
end
