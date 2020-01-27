defmodule TransactionalOutbox.MessageRelay.EventProcessorTest do
  import Mox
  use TransactionalOutbox.DataCase, async: false

  alias TransactionalOutbox.Repo

  alias TransactionalOutbox.MessageRelay.EventProcessor
  alias TransactionalOutbox.Outbox.Event

  setup :verify_on_exit!

  describe "#process/3" do
    test "call the dispatcher and remove from the outbox table" do
      expect(DispatcherMock, :dispatch, 1, fn %Event{} = event -> {:ok, event} end)
      event = insert!(:event, name: "my_app.test_event", payload: %{hey: "hoo"})

      assert {:ok, %{event: %Event{}, delete_event: %Event{}, publish_message: %Event{}}} =
               EventProcessor.process(event.id, Repo, DispatcherMock)

      assert outbox_table_is_empty?()
    end

    test "returns error when dispatcher doesn't works" do
      expect(DispatcherMock, :dispatch, 1, fn %Event{} -> {:error, :broker_offline} end)
      event = insert!(:event, name: "my_app.test_event", payload: %{hey: "hoo"})

      assert {:error, :publish_message, :broker_offline, %{delete_event: _, event: _}} =
               EventProcessor.process(event.id, Repo, DispatcherMock)

      refute outbox_table_is_empty?()
    end

    test "returns error when the event not exists" do
      invalid_id = "997ba662-4724-49a8-bc80-d332f482666c"

      assert {:error, :event, :event_not_found, %{}} ==
               EventProcessor.process(invalid_id, Repo, DispatcherMock)
    end
  end

  describe "#process_avaiable_events/2" do
    test "call the dispatcher for each event and remove from the outbox table" do
      expect(DispatcherMock, :dispatch, 4, fn %Event{} = event -> {:ok, event} end)

      insert!(:event, name: "my_app.test_event", payload: %{hey: "hoo1"})
      insert!(:event, name: "my_app.test_event", payload: %{hey: "hoo2"})
      insert!(:event, name: "my_app.test_event", payload: %{hey: "hoo3"})
      insert!(:event, name: "my_app.test_event", payload: %{hey: "hoo4"})

      assert [
               {:ok, %{event: %Event{}, delete_event: %Event{}, publish_message: %Event{}}},
               {:ok, %{event: %Event{}, delete_event: %Event{}, publish_message: %Event{}}},
               {:ok, %{event: %Event{}, delete_event: %Event{}, publish_message: %Event{}}},
               {:ok, %{event: %Event{}, delete_event: %Event{}, publish_message: %Event{}}}
             ] = EventProcessor.process_avaiable_events(Repo, DispatcherMock)

      assert outbox_table_is_empty?()
    end
  end

  def insert!(:event, name: name, payload: payload) do
    payload = %{
      event_name: name,
      payload: payload,
      status: %{queued: true}
    }

    %Event{}
    |> Event.changeset(payload)
    |> Repo.insert!()
  end

  def outbox_table_is_empty?, do: Enum.empty?(all_events())
  def all_events, do: Repo.all(Event)
end
