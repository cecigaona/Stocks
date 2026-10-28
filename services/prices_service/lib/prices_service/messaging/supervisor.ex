defmodule PricesService.Messaging.Supervisor do
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      {Registry, keys: :unique, name: PricesService.Messaging.Registry},
      Supervisor.child_spec(
        {PricesService.Messaging.Topic, topic_name: :dead_letter},
        id: :dead_letter_topic
      ),
      Supervisor.child_spec(
        {PricesService.Messaging.Topic, topic_name: :prices_events},
        id: :prices_events_topic
      ),
      PricesService.Messaging.DeadLetterQueue,
      Supervisor.child_spec(
        {PricesService.Messaging.Consumer,
         topic_name: :prices_events,
         handler: PricesService.Messaging.EventsConsumer,
         min_demand: 1,
         max_demand: 10},
        id: :prices_events_consumer
      )
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
