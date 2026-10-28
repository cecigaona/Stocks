defmodule Middleware.Messaging.DeadLetterQueue do
  use GenStage

  alias Middleware.Messaging.Topic

  @table :middleware_dead_letters

  def start_link(opts \\ []) do
    GenStage.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def list_messages do
    case :ets.info(@table) do
      :undefined ->
        []

      _ ->
        @table
        |> :ets.tab2list()
        |> Enum.map(fn {_id, message} -> message end)
        |> Enum.sort_by(& &1.inserted_at, {:desc, DateTime})
    end
  end

  def clear do
    case :ets.info(@table) do
      :undefined ->
        :ok

      _ ->
        :ets.delete_all_objects(@table)
        :ok
    end
  end

  def store(message) do
    :ets.insert(@table, {message.id, message})
    :ok
  end

  @impl true
  def init(opts) do
    topic_name = Keyword.get(opts, :topic_name, :dead_letter)
    min_demand = Keyword.get(opts, :min_demand, 1)
    max_demand = Keyword.get(opts, :max_demand, 10)

    if :ets.info(@table) == :undefined do
      :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    end

    producer = Topic.via_tuple(topic_name)

    {:consumer, %{}, subscribe_to: [{producer, min_demand: min_demand, max_demand: max_demand}]}
  end

  @impl true
  def handle_events(messages, _from, state) do
    for message <- messages do
      store(message)
    end

    {:noreply, [], state}
  end
end
