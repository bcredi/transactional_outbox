defmodule TransactionalOutbox.MessageRelay.EventProcessor do
  @moduledoc false

  import Ecto.Query
  alias Ecto.Multi

  alias TransactionalOutbox.Outbox.Event

  @spec process_avaiable_events(Ecto.Repo.t(), TransactionalOutbox.MessageRelay.Dispatcher.t()) ::
          [
            {:ok, any()}
            | {:error, any()}
            | {:error, Ecto.Multi.name(), any(), %{required(Ecto.Multi.name()) => any()}}
          ]
  def process_avaiable_events(repo, dispatcher) do
    Event
    |> where([e], is_nil(e.status))
    |> repo.all()
    |> Enum.map(&process(&1.id, repo, dispatcher))
  end

  @spec process(String.t(), Ecto.Repo.t(), TransactionalOutbox.MessageRelay.Dispatcher.t()) ::
          {:ok, any()}
          | {:error, any()}
          | {:error, Ecto.Multi.name(), any(), %{required(Ecto.Multi.name()) => any()}}
  def process(event_id, repo, dispatcher) do
    Multi.new()
    |> Multi.run(:event, fn _, _ -> get_event(repo, event_id) end)
    |> Multi.delete(:delete_event, fn %{event: event} -> event end)
    |> Multi.run(:publish_message, fn _, %{event: event} ->
      dispatcher.dispatch(event)
    end)
    |> repo.transaction()
  end

  defp get_event(repo, id) do
    case do_get_event(repo, id) do
      nil -> {:error, :event_not_found}
      :lock_not_available -> {:error, :event_locked}
      %Event{} = event -> {:ok, event}
      error -> {:error, error}
    end
  end

  defp do_get_event(repo, id) do
    Event
    |> where([e], e.id == ^id)
    |> lock("FOR UPDATE NOWAIT")
    |> repo.one()
  rescue
    e in Postgrex.Error ->
      %{postgres: %{code: error_code}} = e
      error_code
  end
end
