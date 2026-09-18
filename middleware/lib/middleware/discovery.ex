defmodule Middleware.Discovery do
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def next_address(service_name) do
    GenServer.call(__MODULE__, {:next, service_name})
  end

  @impl true
  def init(_state) do
    file = System.get_env("SERVICES_FILE", "/app/services.json")
    services = file |> File.read!() |> Jason.decode!()
    counters = for {key, _addresses} <- services, into: %{}, do: {key, 0}

    {:ok, %{services: services, counters: counters}}
  end

  @impl true
  def handle_call({:next, service_name}, _from, state) do
    case Map.get(state.services, service_name, []) do
      [] ->
        {:reply, {:error, :unknown_service}, state}

      addresses ->
        index = Map.get(state.counters, service_name, 0)
        address = Enum.at(addresses, rem(index, length(addresses)))
        counters = Map.put(state.counters, service_name, index + 1)

        {:reply, {:ok, address}, %{state | counters: counters}}
    end
  end
end
