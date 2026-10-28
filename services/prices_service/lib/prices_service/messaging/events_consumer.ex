defmodule PricesService.Messaging.EventsConsumer do
  require Logger

  def handle_message(message) do
    Logger.info("PricesService processed event: #{inspect(message.payload)}")
    :ok
  end
end
