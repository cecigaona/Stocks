defmodule OperationsService.Messaging.EventsConsumer do
  require Logger

  def handle_message(message) do
    Logger.info("OperationsService processed event: #{inspect(message.payload)}")
    :ok
  end
end
