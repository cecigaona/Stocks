defmodule Middleware.Router do
  use Plug.Router

  plug :match

  plug Plug.Parsers,
    parsers: [:json],
    pass: ["*/*"],
    json_decoder: Jason

  plug :dispatch

  match "/api/*_rest" do
    route(conn)
  end

  match _ do
    send_json(conn, 404, %{error: "not found"})
  end

  defp route(conn) do
    conn.request_path
    |> service_for()
    |> dispatch_to_service(conn)
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

  defp dispatch_to_service(nil, conn) do
    send_json(conn, 404, %{error: "unknown route"})
  end

  defp dispatch_to_service(service, conn) do
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
