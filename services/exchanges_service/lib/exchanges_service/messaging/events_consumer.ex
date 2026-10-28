defmodule ExchangesService.Messaging.EventsConsumer do
  require Logger

  def handle_message(message) do
    Logger.info("ExchangesService processed event: #{inspect(message.payload)}")
    :ok
  end
end
