defmodule TransactionalOutbox.Outbox.Migrations do
  @moduledoc false

  use Ecto.Migration

  @table_name "transactional_outbox_events"
  @function_name "transactional_outbox_notify_events_creation"
  @notification_channel "transactional_outbox_event_created"
  @trigger_name "transactional_outbox_event_created"

  def up do
    create table(:transactional_outbox_events, primary_key: false) do
      add(:id, :binary_id, primary_key: true)
      add(:event_name, :string)
      add(:payload, :map)
      add(:status, :map)

      timestamps()
    end

    execute("""
      CREATE OR REPLACE FUNCTION #{@function_name}()
      RETURNS trigger AS $$
      BEGIN
        PERFORM pg_notify(
          '#{@notification_channel}',
          json_build_object(
            'record', row_to_json(NEW)
          )::text
        );
        RETURN NULL;
      END;
      $$ LANGUAGE plpgsql;
    """)

    execute("DROP TRIGGER IF EXISTS #{@trigger_name} ON #{@table_name}")

    execute("""
      CREATE TRIGGER #{@trigger_name}
      AFTER INSERT
      ON #{@table_name}
      FOR EACH ROW
      EXECUTE PROCEDURE #{@function_name}()
    """)
  end

  def down do
    execute("DROP TRIGGER IF EXISTS #{@trigger_name} ON #{@table_name}")
    execute("DROP FUNCTION IF EXISTS #{@function_name} CASCADE")
    drop(table(:transactional_outbox_events))
  end
end
