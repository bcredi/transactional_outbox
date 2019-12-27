defmodule TransactionalOutboxTest do
  use ExUnit.Case
  doctest TransactionalOutbox

  test "greets the world" do
    assert TransactionalOutbox.hello() == :world
  end
end
