defmodule TransactionalOutbox.Repo.Migrations.AddMessageBrokerPublisher do
  use Ecto.Migration

  alias TransactionalOutbox.Outbox.Migrations

  def up, do: Migrations.up()
  def down, do: Migrations.down()
end
