defmodule Middleware.Messaging.EventsConsumer do
  require Logger

  def handle_message(message) do
    Logger.info("Middleware processed event: #{inspect(message.payload)}")
    :ok
  end
end
