defmodule OperationsService.Messaging.Supervisor do
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      {Registry, keys: :unique, name: OperationsService.Messaging.Registry},
      Supervisor.child_spec(
        {OperationsService.Messaging.Topic, topic_name: :dead_letter},
        id: :dead_letter_topic
      ),
      Supervisor.child_spec(
        {OperationsService.Messaging.Topic, topic_name: :operations_events},
        id: :operations_events_topic
      ),
      OperationsService.Messaging.DeadLetterQueue,
      Supervisor.child_spec(
        {OperationsService.Messaging.Consumer,
         topic_name: :operations_events,
         handler: OperationsService.Messaging.EventsConsumer,
         min_demand: 1,
         max_demand: 10},
        id: :operations_events_consumer
      )
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
