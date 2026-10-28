defmodule PricesService.Messaging.Topic do
  use GenStage

  alias PricesService.Messaging.Message
  alias PricesService.Messaging.DeadLetterQueue

  defstruct [:topic_name, :queue, :demand, :max_queue]

  def start_link(opts) do
    topic_name = Keyword.fetch!(opts, :topic_name)
    GenStage.start_link(__MODULE__, opts, name: via_tuple(topic_name))
  end

  def publish(topic_name, payload, max_retries \\ 3) do
    message = Message.new(topic_name, payload, max_retries)

    case GenStage.call(via_tuple(topic_name), {:publish, message}) do
      :ok ->
        :ok

      {:error, :overloaded} = error ->
        DeadLetterQueue.store(message)
        error
    end
  end

  def publish_message(topic_name, %Message{} = message) do
    GenStage.call(via_tuple(topic_name), {:publish, message})
  end

  def via_tuple(topic_name) do
    {:via, Registry, {PricesService.Messaging.Registry, topic_name}}
  end

  @impl true
  def init(opts) do
    topic_name = Keyword.fetch!(opts, :topic_name)

    state = %__MODULE__{
      topic_name: topic_name,
      queue: :queue.new(),
      demand: 0,
      max_queue: Keyword.get(opts, :max_queue, 1_000)
    }

    {:producer, state}
  end

  @impl true
  def handle_call({:publish, message}, _from, state) do
    if :queue.len(state.queue) >= state.max_queue do
      {:reply, {:error, :overloaded}, [], state}
    else
      queue = :queue.in(message, state.queue)
      {:noreply, events, updated_state} = dispatch_events(%{state | queue: queue}, [])
      {:reply, :ok, events, updated_state}
    end
  end

  @impl true
  def handle_demand(incoming_demand, state) do
    total_demand = state.demand + incoming_demand
    dispatch_events(%{state | demand: total_demand}, [])
  end

  defp dispatch_events(%{demand: demand} = state, events) when demand <= 0 do
    {:noreply, Enum.reverse(events), state}
  end

  defp dispatch_events(%{demand: demand, queue: queue} = state, events) do
    case :queue.out(queue) do
      {{:value, message}, remaining_queue} ->
        dispatch_events(
          %{state | demand: demand - 1, queue: remaining_queue},
          [message | events]
        )

      {:empty, _} ->
        {:noreply, Enum.reverse(events), state}
    end
  end
end
