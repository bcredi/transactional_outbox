defmodule TransactionalOutbox.MessageRelay do
  @moduledoc """
  MessageRelay listen for new events/messages in the `Outbox` table
  and dispatch them for the configured handler.
  """

  use GenServer

  import Ecto.Query
  alias Ecto.Multi
  alias Postgrex.Notifications

  alias TransactionalOutbox.Outbox.Event

  require Logger

  @channel "event_created"

  @spec start_link(%{repo: any}) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(%{repo: _} = config) do
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  @spec listen(Struct.t(), String.t()) :: {:error, any} | {:ok, pid, reference}
  def listen(repo, channel) do
    with {:ok, pid} <- Notifications.start_link(repo.config()),
         {:ok, ref} <- Notifications.listen(pid, channel) do
      {:ok, pid, ref}
    end
  end

  @impl GenServer
  def init(%{repo: repo} = config) do
    case listen(repo, @channel) do
      {:ok, _pid, _ref} -> {:ok, config, {:continue, :process_available_events}}
      error -> {:stop, error}
    end
  end

  @impl GenServer
  def handle_continue(:process_available_events, %{repo: repo} = state) do
    Event
    |> where([e], is_nil(e.status))
    |> repo.all()
    |> Enum.each(&process_event(&1.id, state))

    {:noreply, state}
  end

  @impl GenServer
  def handle_info({:notification, _pid, _ref, @channel, payload}, state) do
    case Jason.decode(payload) do
      {:ok, %{"record" => %{"id" => id}}} -> process_event(id, state)
      error -> {:stop, error, []}
    end
  end

  def handle_info(_, state) do
    {:noreply, state}
  end

  defp process_event(id, %{repo: repo} = state) do
    Multi.new()
    |> Multi.run(:event, fn _, _ -> get_event(repo, id) end)
    |> Multi.delete(:delete_event, fn %{event: event} -> event end)
    |> Multi.run(:publish_message, fn _, %{event: event} ->
      ## Publisher.publish_event(publisher_name, event)
      # call the adapter
      {:ok, :ok}
    end)
    |> repo.transaction()
    |> handle_transaction_result(id, state)
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

  defp handle_transaction_result(result, id, %{repo: repo} = state) do
    case result do
      {:ok, _changes} ->
        {:noreply, state}

      {:error, :event, :event_not_found, _} ->
        Logger.debug("Event ##{id} not found.")
        {:noreply, state}

      {:error, :event, :event_locked, _} ->
        Logger.debug("Event ##{id} locked.")
        {:noreply, state}

      {:error, :event, sql_error, _} ->
        {:stop, "SQL Error: #{sql_error}", []}

      {:error, action, error, %{event: %Event{} = event}} ->
        mark_as_error!(repo, event, action, error)
        {:noreply, state}
    end
  end

  defp mark_as_error!(repo, %{status: status} = event, action, error) do
    {:ok, now} = DateTime.now("Etc/UTC")

    new_status =
      Map.put(status, to_string(now), %{
        "type" => "error",
        "action" => to_string(action),
        "message" => :erlang.term_to_binary(error)
      })

    event
    |> Ecto.Changeset.change(status: new_status)
    |> repo.update!()
  end
end
