defmodule ViaTest do
  use ExUnit.Case
  doctest Via

  test "greets the world" do
    assert Via.hello() == :world
  end
end
