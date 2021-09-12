defmodule Command.StartWithSupervisorTest do
  use ExUnit.Case
  require Logger

  setup do
    full_config = Via.Application.start_test()
    {:ok, full_config}
  end

  test "Start With Supervisor", full_config do
    # Expects comments from Gps operator
   config = Configuration.FixedWing.RfCessna2m.Sim.Command.config()
    Command.Supervisor.start_link(config)
    Process.sleep(1000)
  end
end
