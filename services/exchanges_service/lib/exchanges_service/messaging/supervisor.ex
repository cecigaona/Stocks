defmodule ExchangesService.Messaging.Supervisor do
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      {Registry, keys: :unique, name: ExchangesService.Messaging.Registry},
      Supervisor.child_spec(
        {ExchangesService.Messaging.Topic, topic_name: :dead_letter},
        id: :dead_letter_topic
      ),
      Supervisor.child_spec(
        {ExchangesService.Messaging.Topic, topic_name: :exchanges_events},
        id: :exchanges_events_topic
      ),
      ExchangesService.Messaging.DeadLetterQueue,
      Supervisor.child_spec(
        {ExchangesService.Messaging.Consumer,
         topic_name: :exchanges_events,
         handler: ExchangesService.Messaging.EventsConsumer,
         min_demand: 1,
         max_demand: 10},
        id: :exchanges_events_consumer
      )
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
