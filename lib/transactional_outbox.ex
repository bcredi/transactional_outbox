defmodule TransactionalOutbox do
  @moduledoc """
  A library to publish events atomically!

  ## Components

  The library is composed by the following componenets:

  - `TransactionalOutbox.MessageRelay.Dispatcher`: Publish an event in the external service
  like rabbitmq.
  - `TransactionalOutbox.MessageRelay.EventProcessor`: Retrieve the event from database,
  call the dispatcher and remove it atomically.
  - `TransactionalOutbox.Outbox.EventBuilder`: Build your domain events and persist to
  the database.

  ## How to use

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

  Define an event using the `TransactionalOutbox.Outbox.EventBuilder`.

      defmodule MyApp.Accounts.UserCreated do
        use TransactionalOutbox.Outbox.EventBuilder,
          as: "my_app.user.created",
          version: "1.0"

        defstruct ~w(id name email)a
      end

  Now, just publish your domain events using `Ecto.Multi`

        defmodule MyApp.Accounts do
          alias Ecto.Multi

          alias MyApp.Accounts.{User, UserCreated, Profile}

          def create_user(%{} = params, user) do
            Multi.new()
            |> Multi.insert(:user, User.changeset(params))
            |> Multi.run(:user_created, fn repo, %{user: user} ->
              user |> UserCreated.new() |> repo.insert()
            end)
            |> Multi.run(:user_created_event, fn repo, %{user_created: user_created_event} ->
              user_created_event |> MyApp.MessageRelayWorker.new() |> Oban.insert()
            end)
            |> Multi.run(:profile, fn repo, %{user: user} ->
              user |> Profile.changeset() |> repo.insert()
            end)
          end
        end

  ## Oban integration

  In the last version, we provide a server that listen for postgres notifications
  and call the `EventProcessor`. But, the team behind Oban is making a great job
  and we want to take advantages of their functionallity.

  To use it, just implement the worker module

        defmodule MyApp.MessageRelayWorker do
          use Oban.Worker, queue: :message_relay

          alias TransactionalOutbox.MessageRelay.EventProcessor

          @impl Oban.Worker
          def perform(%{"id" => id} = args, _job) do
            EventProcessor.process(id, MyApp.Repo, MyApp.AMQPDispatcher)
          end
        end
  """
end
