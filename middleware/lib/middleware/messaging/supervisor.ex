defmodule Middleware.Messaging.Supervisor do
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      {Registry, keys: :unique, name: Middleware.Messaging.Registry},
      Supervisor.child_spec(
        {Middleware.Messaging.Topic, topic_name: :dead_letter},
        id: :dead_letter_topic
      ),
      Supervisor.child_spec(
        {Middleware.Messaging.Topic, topic_name: :middleware_events},
        id: :middleware_events_topic
      ),
      Middleware.Messaging.DeadLetterQueue,
      Supervisor.child_spec(
        {Middleware.Messaging.Consumer,
         topic_name: :middleware_events,
         handler: Middleware.Messaging.EventsConsumer,
         min_demand: 1,
         max_demand: 10},
        id: :middleware_events_consumer
      )
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
