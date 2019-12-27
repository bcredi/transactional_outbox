defmodule TransactionalOutbox do
  @moduledoc """
  A library to publish events atomically!


  ## How to use

  Configure the dispatcher in the *config.exs*

      ```
      config :message_relay,
        dispatcher: MyApp.AMQPDispatcher
      ```

  Implement the dispatcher module:

      ```
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
      ```

  Initialize the `TransactionalOutbox.MessageRelay` with your application

      ```
      defmodule MyApp.Application do
        ...

        def start(_type, _args) do
          children =
            [
              MyApp.Repo,
              TransactionalOutbox.MessageRelay
            ]

          Supervisor.start_link(children, strategy: :one_for_one, name: MyApp.Supervisor)
        end

        ...
      end
      ```

  Define an event using the `TransactionalOutbox.Outbox.EventBuilder`.

      ```
      defmodule MyApp.Accounts.UserCreated do
        use TransactionalOutbox.Outbox.EventBuilder,
          as: "my_app.user.created",
          version: "1.0"

        defstruct ~w(id name email)a
      end
      ```

  Now, just publish your domain events using `Ecto.Multi`

        ```
        defmodule MyApp.Accounts do
          alias Ecto.Multi

          alias MyApp.Accounts.{User, UserCreated, Profile}

          def create_user(%{} = params, user) do
            Multi.new()
            |> Multi.insert(:user, User.changeset(params))
            |> Multi.run(:user_created, fn repo, %{user: user} ->
              user
              |> UserCreated.new(user)
              |> repo.insert()
            end)
            |> Multi.run(:profile, fn repo, %{user: user} ->
              user
              |> Profile.changeset()
              |> repo.insert()
            end)
          end
        end
        ```
  """
end
