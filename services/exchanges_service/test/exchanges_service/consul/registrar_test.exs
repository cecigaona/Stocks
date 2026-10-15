defmodule ExchangesService.Consul.RegistrarTest do
  use ExUnit.Case, async: false

  alias ExchangesService.Consul.Registrar

  setup do
    bypass = Bypass.open()
    consul_url = "http://localhost:#{bypass.port}"
    {:ok, bypass: bypass, consul_url: consul_url}
  end

  test "registra el servicio exitosamente en Consul con los metadatos y health check correctos", %{
    bypass: bypass,
    consul_url: consul_url
  } do
    test_pid = self()

    Bypass.expect_once(bypass, "PUT", "/v1/agent/service/register", fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      payload = Jason.decode!(body)

      assert payload["Name"] == "test_stock_service"
      assert payload["Address"] == "127.0.0.1"
      assert payload["Port"] == 4001
      assert payload["Tags"] == ["backend", "test"]
      assert payload["Check"]["HTTP"] == "http://127.0.0.1:4001/health"
      assert payload["Check"]["Interval"] == "5s"
      assert payload["Check"]["Timeout"] == "2s"
      assert payload["Check"]["DeregisterCriticalServiceAfter"] == "15s"

      send(test_pid, :registered_received)
      Plug.Conn.resp(conn, 200, "true")
    end)

    Bypass.stub(bypass, "PUT", "/v1/agent/service/deregister/test_stock_service-inst-1", fn conn ->
      Plug.Conn.resp(conn, 200, "true")
    end)

    {:ok, pid} =
      Registrar.start_link(
        name: nil,
        enabled: true,
        consul_url: consul_url,
        service_name: "test_stock_service",
        service_address: "127.0.0.1",
        service_port: 4001,
        tags: ["backend", "test"],
        health_interval: "5s",
        health_timeout: "2s",
        deregister_critical_service_after: "15s",
        instance_id: "inst-1"
      )

    assert_receive :registered_received, 2000
    assert Registrar.registered?(pid) == true

    GenServer.stop(pid)
  end

  test "reintenta el registro con backoff exponencial cuando Consul no está disponible", %{
    bypass: bypass,
    consul_url: consul_url
  } do
    test_pid = self()

    Bypass.expect(bypass, fn conn ->
      if conn.request_path == "/v1/agent/service/register" do
        send(test_pid, :register_attempt)
        Plug.Conn.resp(conn, 500, "Internal Server Error")
      else
        Plug.Conn.resp(conn, 404, "Not Found")
      end
    end)

    {:ok, pid} =
      Registrar.start_link(
        name: nil,
        enabled: true,
        consul_url: consul_url,
        service_name: "test_retry_service",
        initial_delay_ms: 50,
        max_delay_ms: 200,
        instance_id: "inst-retry"
      )

    assert_receive :register_attempt, 1000
    assert Registrar.registered?(pid) == false

    Bypass.expect(bypass, fn conn ->
      cond do
        conn.request_path == "/v1/agent/service/register" ->
          send(test_pid, :register_retry_success)
          Plug.Conn.resp(conn, 200, "true")

        String.starts_with?(conn.request_path, "/v1/agent/service/deregister/") ->
          Plug.Conn.resp(conn, 200, "true")

        true ->
          Plug.Conn.resp(conn, 404, "Not Found")
      end
    end)

    assert_receive :register_retry_success, 1000
    assert Registrar.registered?(pid) == true

    GenServer.stop(pid)
  end

  test "ejecuta deregister ordenado en terminate/2 al producirse un shutdown limpio", %{
    bypass: bypass,
    consul_url: consul_url
  } do
    test_pid = self()
    service_id = "test_deregister_service-inst-clean"

    Bypass.expect_once(bypass, "PUT", "/v1/agent/service/register", fn conn ->
      Plug.Conn.resp(conn, 200, "true")
    end)

    Bypass.expect_once(bypass, "PUT", "/v1/agent/service/deregister/#{service_id}", fn conn ->
      send(test_pid, :deregister_called)
      Plug.Conn.resp(conn, 200, "true")
    end)

    {:ok, pid} =
      Registrar.start_link(
        name: nil,
        enabled: true,
        consul_url: consul_url,
        service_name: "test_deregister_service",
        instance_id: "inst-clean"
      )

    Process.sleep(50)
    assert Registrar.registered?(pid) == true

    GenServer.stop(pid)

    assert_receive :deregister_called, 2000
  end
end
