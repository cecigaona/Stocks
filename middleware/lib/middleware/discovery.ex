defmodule Middleware.Discovery do
  use GenServer
  require Logger

  @cache_table :middleware_discovery_cache
  @rr_table :middleware_discovery_counters
  @default_ttl_ms 3_000

  defstruct [
    :consul_url,
    :ttl_ms,
    :fallback_file,
    :http_client
  ]

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def next_address(service_name) do
    case pick_instance(service_name, :round_robin) do
      {:ok, %{url: url}} -> {:ok, url}
      {:ok, url} when is_binary(url) -> {:ok, url}
      {:error, reason} -> {:error, reason}
    end
  end

  def healthy_instances(service_name, opts \\ []) do
    use_cache = Keyword.get(opts, :cache, true)

    if use_cache do
      get_with_cache(service_name, opts)
    else
      fetch_from_consul(service_name)
    end
  end

  def pick_instance(service_name, strategy \\ :round_robin, opts \\ []) do
    case healthy_instances(service_name, opts) do
      {:ok, []} ->
        fallback_next_address(service_name)

      {:ok, instances} ->
        {:ok, select_instance(service_name, instances, strategy)}

      {:error, _reason} ->
        fallback_next_address(service_name)
    end
  end

  defp select_instance(_service_name, [single], _strategy), do: single

  defp select_instance(_service_name, instances, :random) do
    Enum.random(instances)
  end

  defp select_instance(service_name, instances, :round_robin) do
    counter =
      try do
        :ets.update_counter(@rr_table, service_name, {2, 1}, {service_name, 0})
      rescue
        _ -> :rand.uniform(length(instances))
      end

    index = rem(counter, length(instances))
    Enum.at(instances, index)
  end

  @impl true
  def init(opts) do
    consul_host = System.get_env("CONSUL_HOST", "consul")
    consul_port = System.get_env("CONSUL_PORT", "8500")
    consul_url = Keyword.get(opts, :consul_url, "http://#{consul_host}:#{consul_port}")
    ttl_ms = Keyword.get(opts, :ttl_ms, @default_ttl_ms)
    fallback_file = System.get_env("SERVICES_FILE", "/app/services.json")
    http_client = Keyword.get(opts, :http_client, Req)

    if :ets.info(@cache_table) == :undefined do
      :ets.new(@cache_table, [:named_table, :public, :set, read_concurrency: true])
    end

    if :ets.info(@rr_table) == :undefined do
      :ets.new(@rr_table, [:named_table, :public, :set, write_concurrency: true])
    end

    state = %__MODULE__{
      consul_url: consul_url,
      ttl_ms: ttl_ms,
      fallback_file: fallback_file,
      http_client: http_client
    }

    Logger.info("[Middleware.Discovery] Inicializado con Consul en #{consul_url} (Cache TTL: #{ttl_ms}ms)")

    {:ok, state}
  end

  @impl true
  def handle_call(:get_config, _from, state) do
    {:reply, state, state}
  end

  defp get_with_cache(service_name, opts) do
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(@cache_table, service_name) do
      [{^service_name, instances, expires_at}] when now < expires_at ->
        {:ok, instances}

      stale_record ->
        case fetch_from_consul(service_name) do
          {:ok, instances} when instances != [] ->
            ttl = Keyword.get(opts, :ttl_ms, get_ttl())
            :ets.insert(@cache_table, {service_name, instances, now + ttl})
            {:ok, instances}

          _fallback_needed ->
            case stale_record do
              [{^service_name, instances, _}] ->
                Logger.warning("[Middleware.Discovery] Consul inaccesible. Sirviendo caché stale para #{service_name}")
                {:ok, instances}

              _ ->
                {:error, :no_healthy_instances}
            end
        end
    end
  end

  def fetch_from_consul(service_name) do
    config = get_config()
    url = "#{config.consul_url}/v1/health/service/#{service_name}?passing=true"

    case config.http_client.get(url) do
      {:ok, %{status: 200, body: raw_body}} ->
        entries =
          case raw_body do
            list when is_list(list) -> list
            binary when is_binary(binary) ->
              case Jason.decode(binary) do
                {:ok, list} when is_list(list) -> list
                _ -> []
              end
            _ -> []
          end

        instances =
          entries
          |> Enum.map(&parse_consul_service_entry/1)
          |> Enum.reject(&is_nil/1)

        {:ok, instances}

      {:ok, %{status: status, body: body}} ->
        Logger.error("[Middleware.Discovery] Error consultando Consul (#{status}): #{inspect(body)}")
        {:error, {:consul_http_error, status, body}}

      {:error, reason} ->
        Logger.error("[Middleware.Discovery] Error de red consultando Consul: #{inspect(reason)}")
        {:error, {:consul_network_error, reason}}
    end
  rescue
    e ->
      Logger.error("[Middleware.Discovery] Excepción consultando Consul: #{Exception.message(e)}")
      {:error, e}
  end

  defp parse_consul_service_entry(%{"Service" => service, "Node" => node}) do
    address =
      case service["Address"] do
        addr when is_binary(addr) and addr != "" -> addr
        _ -> node["Address"]
      end

    port = service["Port"]
    id = service["ID"]
    name = service["Service"]
    tags = service["Tags"] || []

    %{
      id: id,
      name: name,
      address: address,
      port: port,
      url: "http://#{address}:#{port}",
      tags: tags
    }
  end

  defp parse_consul_service_entry(_), do: nil

  defp fallback_next_address(service_name) do
    file = System.get_env("SERVICES_FILE", "/app/services.json")

    with true <- File.exists?(file),
         {:ok, content} <- File.read(file),
         {:ok, services} <- Jason.decode(content),
         addresses when is_list(addresses) and addresses != [] <- Map.get(services, service_name) do
      Logger.warning("[Middleware.Discovery] Usando archivo fallback services.json para #{service_name}")
      counter = :ets.update_counter(@rr_table, service_name, {2, 1}, {service_name, 0})
      address = Enum.at(addresses, rem(counter, length(addresses)))
      {:ok, %{url: address, id: "fallback", name: service_name}}
    else
      _ ->
        {:error, :service_unavailable}
    end
  rescue
    _ -> {:error, :service_unavailable}
  end

  defp get_config do
    GenServer.call(__MODULE__, :get_config)
  catch
    :exit, _ ->
      %{
        consul_url:
          "http://#{System.get_env("CONSUL_HOST", "consul")}:#{System.get_env("CONSUL_PORT", "8500")}",
        ttl_ms: @default_ttl_ms,
        http_client: Req
      }
  end

  defp get_ttl do
    case get_config() do
      %{ttl_ms: ttl} -> ttl
      _ -> @default_ttl_ms
    end
  end
end
