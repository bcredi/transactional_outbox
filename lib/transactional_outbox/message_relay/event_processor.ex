defmodule TransactionalOutbox.MessageRelay.EventProcessor do
  @moduledoc """
  Event Processor module.
  Use this module to process events that you want.
  """

  import Ecto.Query
  alias Ecto.Multi

  alias TransactionalOutbox.Outbox.Event

  @doc """
  Process all events in the outbox table.

  ## Examples

      iex> process_avaiable_events(MyApp.Repo, MyApp.AMQPDispatcher)
      [{:ok, %{event: %Event{}, delete_event: %Event{}, publish_message: %Event{}}}, ...]

  """
  @spec process_avaiable_events(Ecto.Repo.t(), TransactionalOutbox.MessageRelay.Dispatcher.t()) ::
          [
            {:ok, any()}
            | {:error, Ecto.Multi.name(), any(), %{required(Ecto.Multi.name()) => any()}}
          ]
  def process_avaiable_events(repo, dispatcher) do
    Event
    |> where([e], is_nil(e.status))
    |> repo.all()
    |> Enum.map(&process(&1.id, repo, dispatcher))
  end

  @doc """
  Process an event.
  The record will be locked for update in the database.

  ## Examples

      iex> process("b507ad11-81ee-4802-a0d0-9e3ed8444d8d", MyApp.Repo, MyApp.AMQPDispatcher)
      {:ok, %{event: %Event{}, delete_event: %Event{}, publish_message: %Event{}}}

      iex> process("b877af4c-71b5-4a00-8b0a-999574b20a8b", MyApp.Repo, MyApp.AMQPDispatcher)
      {:error, :event, :event_not_found, %{}}

      iex> process("b877af4c-71b5-4a00-8b0a-999574b20a8b", MyApp.Repo, MyApp.AMQPDispatcher)
      {:error, :event, :event_locked, %{}}

  """
  @spec process(String.t(), Ecto.Repo.t(), TransactionalOutbox.MessageRelay.Dispatcher.t()) ::
          {:ok, map()}
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
