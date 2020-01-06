defmodule TransactionalOutbox.Outbox.Event do
  @type uuid :: String.t()

  @type t :: %__MODULE__{
          id: uuid(),
          event_name: String.t(),
          payload: map(),
          status: map()
        }

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "transactional_outbox_events" do
    field(:event_name, :string)
    field(:payload, :map)
    field(:status, :map)

    timestamps()
  end

  @doc false
  def changeset(event, attrs) do
    event
    |> cast(attrs, [:event_name, :payload])
    |> validate_required([:event_name, :payload])
  end
end
