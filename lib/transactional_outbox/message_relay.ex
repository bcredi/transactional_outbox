defmodule TransactionalOutbox.MessageRelay do
  @moduledoc """
  MessageRelay listen for new records in the `transactional_outbox_events` table
  and dispatch them for the configured handler.
  """

  defmodule InvalidConfigError do
    defexception message: "The given config is invalid!"
  end

  use GenServer

  import Ecto.Query
  alias Ecto.Multi
  alias Postgrex.Notifications

  alias TransactionalOutbox.Outbox.Event

  require Logger

  @channel "transactional_outbox_event_created"

  @spec start_link(%{repo: any}) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(config) do
    if not valid_config?(config), do: raise(InvalidConfigError)
    GenServer.start_link(__MODULE__, config, name: __MODULE__)
  end

  defp valid_config?(%{repo: _, dispatcher: _}), do: true
  defp valid_config?(_), do: false

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
  def handle_continue(:process_available_events, %{repo: repo, dispatcher: dispatcher} = state) do
    TransactionalOutbox.MessageRelay.EventProcessor.process_avaiable_events(repo, dispatcher)
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

  defp process_event(id, %{repo: repo, dispatcher: dispatcher} = state) do
    TransactionalOutbox.MessageRelay.EventProcessor.process(id, repo, dispatcher)
    |> handle_transaction_result(id, state)
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
