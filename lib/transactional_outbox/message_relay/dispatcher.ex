defmodule TransactionalOutbox.MessageRelay.Dispatcher do
  @type t :: module
  @type event :: any()
  @type reason :: String.t()

  @callback dispatch(event()) :: {:ok, event()} | {:error, reason()}
end
