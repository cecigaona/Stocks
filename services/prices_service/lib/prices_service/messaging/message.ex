defmodule PricesService.Messaging.Message do
  defstruct [
    :id,
    :topic,
    :payload,
    retry_count: 0,
    max_retries: 3,
    inserted_at: nil,
    error_reason: nil
  ]

  def new(topic, payload, max_retries \\ 3) do
    %__MODULE__{
      id: :crypto.strong_rand_bytes(12) |> Base.encode16(case: :lower),
      topic: topic,
      payload: payload,
      retry_count: 0,
      max_retries: max_retries,
      inserted_at: DateTime.utc_now()
    }
  end
end
