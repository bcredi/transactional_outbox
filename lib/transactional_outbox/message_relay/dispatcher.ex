defmodule TransactionalOutbox.MessageRelay.Dispatcher do
  @moduledoc """
  Dispatcher behaviour.

  Implement the dispatcher module:

      defmodule MyApp.AMQPDispatcher do
        @behaviour TransactionalOutbox.MessageRelay.Dispatcher

        import Conduit.Message
        alias Conduit.Message

        alias MyApp.Broker

        alias TransactionalOutbox.Outbox.Event

        def dispatch(%Event{} = event) do
          %Message{}
          |> put_body(event.payload)
          |> assign(:user_id, event.user_id)
          |> put_header("version", event.version)
          |> Broker.publish(:user_created)
        end
      end

  Configure the dispatcher in the *config.exs*

      config :my_app, TransactionalOutbox.MessageRelay.Dispatcher,
        MyApp.AMQPDispatcher

  """
  @type t :: module
  @type event :: TransactionalOutbox.Outbox.Event.t()
  @type reason :: String.t()

  @callback dispatch(event()) :: {:ok, event()} | {:error, reason()}
end
