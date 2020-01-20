ExUnit.start()
# Faker.start()

{:ok, _pid} =
  Supervisor.start_link([TransactionalOutbox.Repo],
    strategy: :one_for_one,
    name: TransactionalOutbox.Test.Supervisor
  )

Ecto.Adapters.SQL.Sandbox.mode(TransactionalOutbox.Repo, :manual)
