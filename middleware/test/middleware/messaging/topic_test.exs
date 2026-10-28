defmodule Middleware.Messaging.TopicTest do
  use ExUnit.Case, async: false

  alias Middleware.Messaging.DeadLetterQueue
  alias Middleware.Messaging.Message
  alias Middleware.Messaging.Topic

  setup do
    topic_name = {:test_topic, System.unique_integer([:positive])}
    start_supervised!({Topic, topic_name: topic_name, max_queue: 1})
    {:ok, topic_name: topic_name}
  end

  test "stores rejected messages in the dead-letter queue", %{topic_name: topic_name} do
    assert :ok = Topic.publish(topic_name, :first)
    assert {:error, :overloaded} = Topic.publish(topic_name, :second)
    assert Enum.any?(DeadLetterQueue.list_messages(), &match?(%Message{payload: :second}, &1))
  end
end
