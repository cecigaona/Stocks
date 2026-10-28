defmodule Middleware.Router do
  use Plug.Router

  alias Middleware.Grpc.Client, as: GrpcClient

  plug :match

  plug Plug.Parsers,
    parsers: [:json],
    pass: ["*/*"],
    json_decoder: Jason

  plug :dispatch

  get "/api/exchanges" do
    case GrpcClient.list_exchanges() do
      {:ok, resp} ->
        data = Enum.map(resp.exchanges, fn e -> %{id: e.id, name: e.name, code: e.code} end)
        send_json(conn, 200, %{data: data})

      _ ->
        dispatch_fallback(conn, "exchanges_service")
    end
  end

  get "/api/exchanges/:id/stocks" do
    case Integer.parse(id) do
      {exchange_id, ""} ->
        case GrpcClient.list_stocks_by_exchange(exchange_id) do
          {:ok, resp} ->
            data = Enum.map(resp.stocks, &stock_to_map/1)
            send_json(conn, 200, %{data: data})

          _ ->
            dispatch_fallback(conn, "exchanges_service")
        end

      _ ->
        send_json(conn, 400, %{error: "invalid exchange id"})
    end
  end

  get "/api/stocks" do
    case GrpcClient.list_stocks() do
      {:ok, resp} ->
        data = Enum.map(resp.stocks, &stock_to_map/1)
        send_json(conn, 200, %{data: data})

      _ ->
        dispatch_fallback(conn, "exchanges_service")
    end
  end

  get "/api/prices" do
    case GrpcClient.list_prices() do
      {:ok, resp} ->
        data = Enum.map(resp.prices, &price_to_map/1)
        send_json(conn, 200, %{data: data})

      _ ->
        dispatch_fallback(conn, "prices_service")
    end
  end

  get "/api/prices/:symbol" do
    case GrpcClient.get_price(symbol) do
      {:ok, resp} ->
        send_json(conn, 200, %{data: price_to_map(resp.price)})

      {:error, %GRPC.RPCError{status: 5}} ->
        send_json(conn, 404, %{error: "price not found"})

      _ ->
        dispatch_fallback(conn, "prices_service")
    end
  end

  get "/api/operations" do
    case GrpcClient.list_operations() do
      {:ok, resp} ->
        data = Enum.map(resp.operations, &operation_to_map/1)
        send_json(conn, 200, %{data: data})

      _ ->
        dispatch_fallback(conn, "operations_service")
    end
  end

  post "/api/operations" do
    case GrpcClient.create_operation(conn.body_params) do
      {:ok, resp} ->
        send_json(conn, 201, operation_to_map(resp.operation))

      {:error, %GRPC.RPCError{status: 3, message: msg}} ->
        send_json(conn, 422, %{error: msg})

      {:error, %GRPC.RPCError{status: 5, message: msg}} ->
        send_json(conn, 404, %{error: msg})

      _ ->
        dispatch_fallback(conn, "operations_service")
    end
  end

  get "/api/portfolio" do
    case GrpcClient.get_portfolio() do
      {:ok, resp} ->
        data =
          Enum.map(resp.items, fn item ->
            %{
              symbol: item.symbol,
              quantity: item.quantity,
              net_invested: item.net_invested
            }
          end)

        send_json(conn, 200, %{data: data})

      _ ->
        dispatch_fallback(conn, "operations_service")
    end
  end

  match "/api/*_rest" do
    service = service_for(conn.request_path)
    dispatch_fallback(conn, service)
  end

  match _ do
    send_json(conn, 404, %{error: "not found"})
  end

  defp stock_to_map(s) do
    %{id: s.id, symbol: s.symbol, name: s.name, exchange_id: s.exchange_id}
  end

  defp price_to_map(p) do
    %{id: p.id, symbol: p.symbol, price: p.price, updated_at: p.updated_at}
  end

  defp operation_to_map(op) do
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

  defp service_for(path) do
    cond do
      String.starts_with?(path, "/api/exchanges") -> "exchanges_service"
      String.starts_with?(path, "/api/stocks") -> "exchanges_service"
      String.starts_with?(path, "/api/prices") -> "prices_service"
      String.starts_with?(path, "/api/portfolio") -> "operations_service"
      String.starts_with?(path, "/api/operations") -> "operations_service"
      true -> nil
    end
  end

  defp dispatch_fallback(conn, nil) do
    send_json(conn, 404, %{error: "unknown route"})
  end

  defp dispatch_fallback(conn, service) do
    case Middleware.Discovery.next_address(service) do
      {:ok, base_url} -> proxy(conn, base_url)
      {:error, _reason} -> send_json(conn, 502, %{error: "service unavailable"})
    end
  end

  defp proxy(conn, base_url) do
    url = to_charlist(base_url <> conn.request_path <> query_string(conn))
    method = conn.method |> String.downcase() |> String.to_atom()
    headers = [{~c"content-type", ~c"application/json"}]
    body = request_body(conn)

    request =
      if method in [:post, :put, :patch] do
        {url, headers, ~c"application/json", body}
      else
        {url, headers}
      end

    case :httpc.request(method, request, [], []) do
      {:ok, {{_version, status, _reason}, resp_headers, resp_body}} ->
        conn
        |> put_resp_content_type(content_type(resp_headers))
        |> send_resp(status, resp_body)

      {:error, _reason} ->
        send_json(conn, 502, %{error: "bad gateway"})
    end
  end

  defp request_body(%{body_params: %Plug.Conn.Unfetched{}}), do: ""
  defp request_body(%{body_params: params}) when map_size(params) == 0, do: ""
  defp request_body(%{body_params: params}), do: Jason.encode!(params)

  defp query_string(conn) do
    if conn.query_string == "", do: "", else: "?" <> conn.query_string
  end

  defp content_type(headers) do
    case List.keyfind(headers, ~c"content-type", 0) do
      {_key, value} -> to_string(value)
      nil -> "application/json"
    end
  end

  defp send_json(conn, status, payload) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(status, Jason.encode!(payload))
  end
end
