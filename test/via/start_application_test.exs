
defmodule Via.StartApplicationTest do
  use ExUnit.Case
  require Logger

  test "Start up sim environment" do
    Via.Application.start(nil, nil)
    Process.sleep(2000)
  end
end
