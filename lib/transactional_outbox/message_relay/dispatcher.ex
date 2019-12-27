defmodule TransactionalOutbox.MessageRelay.Dispatcher do
  @type event :: any()
  @type reason :: String.t()

  @callback dispatch(event()) :: {:ok, event()} | {:error, reason()}
end
