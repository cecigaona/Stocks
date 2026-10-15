defmodule ExchangesServiceWeb.HealthControllerTest do
  use ExUnit.Case, async: true
  import Plug.Test
  import Plug.Conn

  alias ExchangesServiceWeb.Router

  @opts Router.init([])

  test "GET /health devuelve 200 cuando la base de datos responde o 503 si falla" do
    conn = conn(:get, "/health")
    conn = Router.call(conn, @opts)

    assert conn.status in [200, 503]
    response = Jason.decode!(conn.resp_body)

    if conn.status == 200 do
      assert response["status"] == "healthy"
      assert response["checks"]["database"] == "passing"
    else
      assert response["status"] == "unhealthy"
      assert response["checks"]["database"] == "critical"
    end
  end
end
