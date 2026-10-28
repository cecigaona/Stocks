defmodule PricesService.Simulator do
  use GenServer

  alias PricesService.Prices

  @interval 5_000

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(state) do
    schedule_tick()
    {:ok, state}
  end

  @impl true
  def handle_info(:tick, state) do
    updated = Prices.fluctuate_all()
    PricesService.Messaging.Topic.publish(:prices_events, {:simulator_tick, %{count: length(updated)}})
    schedule_tick()
    {:noreply, state}
  end

  defp schedule_tick do
    Process.send_after(self(), :tick, @interval)
  end
end
