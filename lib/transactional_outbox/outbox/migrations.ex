defmodule TransactionalOutbox.Outbox.Migrations do
  @moduledoc false

  use Ecto.Migration

  @table_name "message_broker_events"
  @function_name "notify_events_creation"
  @trigger_name "event_created"

  def up do
    create_if_not_exists table(:message_broker_events, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:event_name, :string)
      add(:payload, :map)
      add(:status, :map)

      timestamps()
    end

    execute("DROP TRIGGER IF EXISTS #{@trigger_name} ON #{@table_name}")
    execute("DROP FUNCTION IF EXISTS #{@function_name} CASCADE")
  end

  def down do
    drop(table(:message_broker_events))
  end
end
