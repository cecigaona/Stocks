defmodule PricesServiceWeb.PriceController do
  use Phoenix.Controller, formats: [:json]

  alias PricesService.Prices

  def index(conn, _params) do
    prices = Prices.list_prices()
    json(conn, %{data: Enum.map(prices, &price_json/1)})
  end

  def show(conn, %{"symbol" => symbol}) do
    case Prices.get_price(symbol) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "price not found"})

      price ->
        json(conn, price_json(price))
    end
  end

  defp price_json(p) do
    %{symbol: p.symbol, price: p.price, updated_at: p.updated_at}
  end
end
