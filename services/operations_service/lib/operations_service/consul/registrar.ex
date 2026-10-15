defmodule OperationsService.Consul.Registrar do
  use GenServer
  require Logger

  @default_initial_delay_ms 1_000
  @default_max_delay_ms 30_000

  defstruct [
    :service_id,
    :service_name,
    :service_address,
    :service_port,
    :tags,
    :consul_url,
    :health_url,
    :health_interval,
    :health_timeout,
    :deregister_after,
    :registered,
    :current_delay_ms,
    :max_delay_ms,
    :enabled,
    :http_client
  ]

  def start_link(opts \\ []) do
    case Keyword.get(opts, :name, __MODULE__) do
      nil -> GenServer.start_link(__MODULE__, opts)
      name -> GenServer.start_link(__MODULE__, opts, name: name)
    end
  end

  def registered?(server \\ __MODULE__) do
    GenServer.call(server, :registered?)
  end

  @impl true
  def init(opts) do
    Process.flag(:trap_exit, true)

    config = Application.get_env(:operations_service, :consul, [])
    merged_opts = Keyword.merge(config, opts)

    enabled = Keyword.get(merged_opts, :enabled, true)
    service_name = Keyword.get(merged_opts, :service_name, "operations_service")

    unique_suffix =
      Keyword.get_lazy(merged_opts, :instance_id, fn ->
        case System.get_env("HOSTNAME") do
          nil -> :crypto.strong_rand_bytes(4) |> Base.encode16(case: :lower)
          host -> host
        end
      end)

    service_id = "#{service_name}-#{unique_suffix}"
    service_address = Keyword.get(merged_opts, :service_address, "operations_service")
    service_port = Keyword.get(merged_opts, :service_port, 4003)
    tags = Keyword.get(merged_opts, :tags, ["backend", "operations"])

    consul_host = Keyword.get(merged_opts, :host, "consul")
    consul_port = Keyword.get(merged_opts, :port, 8500)
    consul_url = Keyword.get(merged_opts, :consul_url, "http://#{consul_host}:#{consul_port}")

    health_path = Keyword.get(merged_opts, :health_path, "/health")
    health_url = "http://#{service_address}:#{service_port}#{health_path}"
    health_interval = Keyword.get(merged_opts, :health_interval, "10s")
    health_timeout = Keyword.get(merged_opts, :health_timeout, "3s")
    deregister_after = Keyword.get(merged_opts, :deregister_critical_service_after, "30s")

    state = %__MODULE__{
      service_id: service_id,
      service_name: service_name,
      service_address: service_address,
      service_port: service_port,
      tags: tags,
      consul_url: consul_url,
      health_url: health_url,
      health_interval: health_interval,
      health_timeout: health_timeout,
      deregister_after: deregister_after,
      registered: false,
      current_delay_ms: Keyword.get(merged_opts, :initial_delay_ms, @default_initial_delay_ms),
      max_delay_ms: Keyword.get(merged_opts, :max_delay_ms, @default_max_delay_ms),
      enabled: enabled,
      http_client: Keyword.get(merged_opts, :http_client, Req)
    }

    if enabled do
      {:ok, state, {:continue, :register}}
    else
      {:ok, state}
    end
  end

  @impl true
  def handle_continue(:register, state) do
    {:noreply, attempt_registration(state)}
  end

  @impl true
  def handle_info(:retry_register, state) do
    {:noreply, attempt_registration(state)}
  end

  @impl true
  def handle_call(:registered?, _from, state) do
    {:reply, state.registered, state}
  end

  @impl true
  def terminate(reason, %{registered: true} = state) do
    Logger.info("[Consul.Registrar] Desregistrando #{state.service_id} de Consul (motivo: #{inspect(reason)})...")
    deregister_service(state)
    :ok
  end

  def terminate(_reason, _state), do: :ok

  defp attempt_registration(state) do
    Logger.info("[Consul.Registrar] Registrando #{state.service_id} en Consul (#{state.consul_url})...")

    case register_service(state) do
      {:ok, _status} ->
        Logger.info("[Consul.Registrar] Servicio #{state.service_id} registrado exitosamente en Consul")
        %{state | registered: true, current_delay_ms: @default_initial_delay_ms}

      {:error, reason} ->
        Logger.warning(
          "[Consul.Registrar] Fallo al registrar #{state.service_id} en Consul: #{inspect(reason)}. Reintentando en #{state.current_delay_ms}ms..."
        )

        Process.send_after(self(), :retry_register, state.current_delay_ms)
        next_delay = min(state.current_delay_ms * 2, state.max_delay_ms)
        %{state | registered: false, current_delay_ms: next_delay}
    end
  end

  defp register_service(state) do
    url = "#{state.consul_url}/v1/agent/service/register"

    payload = %{
      "ID" => state.service_id,
      "Name" => state.service_name,
      "Tags" => state.tags,
      "Address" => state.service_address,
      "Port" => state.service_port,
      "Check" => %{
        "HTTP" => state.health_url,
        "Interval" => state.health_interval,
        "Timeout" => state.health_timeout,
        "DeregisterCriticalServiceAfter" => state.deregister_after
      }
    }

    case state.http_client.put(url, json: payload) do
      {:ok, %{status: status}} when status in 200..299 ->
        {:ok, status}

      {:ok, %{status: status, body: body}} ->
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        {:error, reason}
    end
  rescue
    e -> {:error, e}
  end

  defp deregister_service(state) do
    url = "#{state.consul_url}/v1/agent/service/deregister/#{state.service_id}"

    case state.http_client.put(url) do
      {:ok, %{status: status}} when status in 200..299 ->
        Logger.info("[Consul.Registrar] Servicio #{state.service_id} desregistrado exitosamente")
        {:ok, status}

      {:ok, %{status: status, body: body}} ->
        Logger.error("[Consul.Registrar] Error al desregistrar: HTTP #{status} - #{inspect(body)}")
        {:error, {:http_error, status, body}}

      {:error, reason} ->
        Logger.error("[Consul.Registrar] Fallo al desregistrar: #{inspect(reason)}")
        {:error, reason}
    end
  rescue
    e ->
      Logger.error("[Consul.Registrar] Excepción al desregistrar: #{Exception.message(e)}")
      {:error, e}
  end
end
