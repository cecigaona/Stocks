defmodule ExchangesService.Consul.DiscoveryTest do
  use ExUnit.Case, async: false

  alias ExchangesService.Consul.Discovery

  setup do
    bypass = Bypass.open()
    consul_url = "http://localhost:#{bypass.port}"

    if :ets.info(:consul_discovery_cache) != :undefined do
      :ets.delete_all_objects(:consul_discovery_cache)
    end

    if :ets.info(:consul_discovery_counters) != :undefined do
      :ets.delete_all_objects(:consul_discovery_counters)
    end

    case Process.whereis(Discovery) do
      nil -> :ok
      existing_pid -> GenServer.stop(existing_pid)
    end

    {:ok, pid} =
      Discovery.start_link(
        name: Discovery,
        consul_url: consul_url,
        cache_ttl_ms: 200
      )

    on_exit(fn ->
      if Process.alive?(pid), do: GenServer.stop(pid)
    end)

    {:ok, bypass: bypass, consul_url: consul_url}
  end

  test "obtiene instancias saludables desde la API de Consul", %{bypass: bypass} do
    mock_payload = [
      %{
        "Node" => %{"Node" => "node-1", "Address" => "10.0.0.1"},
        "Service" => %{
          "ID" => "stocks-1",
          "Service" => "stocks_service",
          "Address" => "10.0.0.1",
          "Port" => 4001,
          "Tags" => ["api", "v1"]
        }
      },
      %{
        "Node" => %{"Node" => "node-2", "Address" => "10.0.0.2"},
        "Service" => %{
          "ID" => "stocks-2",
          "Service" => "stocks_service",
          "Address" => "10.0.0.2",
          "Port" => 4001,
          "Tags" => ["api", "v1"]
        }
      }
    ]

    Bypass.expect_once(bypass, "GET", "/v1/health/service/stocks_service", fn conn ->
      assert conn.query_string == "passing=true"
      Plug.Conn.resp(conn, 200, Jason.encode!(mock_payload))
    end)

    assert {:ok, instances} = Discovery.healthy_instances("stocks_service", cache: false)
    assert length(instances) == 2

    assert Enum.at(instances, 0) == %{
             id: "stocks-1",
             name: "stocks_service",
             address: "10.0.0.1",
             port: 4001,
             url: "http://10.0.0.1:4001",
             tags: ["api", "v1"]
           }
  end

  test "balancea peticiones con Round-Robin entre múltiples instancias", %{bypass: bypass} do
    mock_payload = [
      %{
        "Node" => %{"Address" => "10.0.0.1"},
        "Service" => %{"ID" => "inst-1", "Service" => "order_service", "Address" => "10.0.0.1", "Port" => 5001}
      },
      %{
        "Node" => %{"Address" => "10.0.0.2"},
        "Service" => %{"ID" => "inst-2", "Service" => "order_service", "Address" => "10.0.0.2", "Port" => 5002}
      }
    ]

    Bypass.expect(bypass, "GET", "/v1/health/service/order_service", fn conn ->
      Plug.Conn.resp(conn, 200, Jason.encode!(mock_payload))
    end)

    {:ok, first} = Discovery.pick_instance("order_service", :round_robin)
    {:ok, second} = Discovery.pick_instance("order_service", :round_robin)
    {:ok, third} = Discovery.pick_instance("order_service", :round_robin)

    assert first.id != second.id
    assert third.id == first.id
  end

  test "utiliza caché ETS con TTL evitando consultas repetidas a Consul", %{bypass: bypass} do
    test_pid = self()

    mock_payload = [
      %{
        "Node" => %{"Address" => "10.0.0.1"},
        "Service" => %{"ID" => "inst-1", "Service" => "cached_service", "Address" => "10.0.0.1", "Port" => 4001}
      }
    ]

    Bypass.expect_once(bypass, "GET", "/v1/health/service/cached_service", fn conn ->
      send(test_pid, :consul_hit)
      Plug.Conn.resp(conn, 200, Jason.encode!(mock_payload))
    end)

    {:ok, inst1} = Discovery.healthy_instances("cached_service", cache: true)
    assert_receive :consul_hit, 500

    {:ok, inst2} = Discovery.healthy_instances("cached_service", cache: true)
    {:ok, inst3} = Discovery.healthy_instances("cached_service", cache: true)

    assert inst1 == inst2
    assert inst2 == inst3

    refute_receive :consul_hit, 100
  end

  test "retorna error si no existen instancias saludables registradas", %{bypass: bypass} do
    Bypass.expect_once(bypass, "GET", "/v1/health/service/empty_service", fn conn ->
      Plug.Conn.resp(conn, 200, "[]")
    end)

    assert {:error, :no_healthy_instances} = Discovery.pick_instance("empty_service")
  end
end
