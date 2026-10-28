defmodule OperationsService.Messaging.Consumer do
  use GenStage

  alias OperationsService.Messaging.Topic
  alias OperationsService.Messaging.DeadLetterQueue

  defstruct [:topic_name, :handler, :dead_letter_topic]

  def start_link(opts) do
    GenStage.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    topic_name = Keyword.fetch!(opts, :topic_name)
    handler = Keyword.fetch!(opts, :handler)
    dead_letter_topic = Keyword.get(opts, :dead_letter_topic, :dead_letter)
    min_demand = Keyword.get(opts, :min_demand, 1)
    max_demand = Keyword.get(opts, :max_demand, 10)

    producer = Topic.via_tuple(topic_name)

    state = %__MODULE__{
      topic_name: topic_name,
      handler: handler,
      dead_letter_topic: dead_letter_topic
    }

    {:consumer, state, subscribe_to: [{producer, min_demand: min_demand, max_demand: max_demand}]}
  end

  @impl true
  def handle_events(messages, _from, state) do
    for message <- messages do
      process_message(message, state)
    end

    {:noreply, [], state}
  end

  defp process_message(message, state) do
    try do
      case state.handler.handle_message(message) do
        :ok ->
          :ok

        {:error, reason} ->
          handle_failure(message, reason, state)
      end
    rescue
      exception ->
        handle_failure(message, exception, state)
    end
  end

  defp handle_failure(message, reason, state) do
    next_retry = message.retry_count + 1
    updated_message = %{message | retry_count: next_retry, error_reason: reason}

    if next_retry < message.max_retries do
      case Topic.publish_message(state.topic_name, updated_message) do
        :ok -> :ok
        {:error, :overloaded} -> send_to_dead_letter(updated_message, state)
      end
    else
      send_to_dead_letter(updated_message, state)
    end
  end

  defp send_to_dead_letter(message, state) do
    case Topic.publish_message(state.dead_letter_topic, message) do
      :ok -> :ok
      {:error, :overloaded} -> DeadLetterQueue.store(message)
    end
  end
end
