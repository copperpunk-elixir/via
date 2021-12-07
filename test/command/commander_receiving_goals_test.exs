defmodule Command.CommanderReceivingGoalsTest do
  use ExUnit.Case
  require Logger

  setup do
    Via.Application.start_test()
    {:ok, []}
  end

  test "Open Serial Port" do
    # Expects comments from Gps operator
    config = Configuration.FixedWing.Cessna2m.Sim.Uart.config(["FrskyRx_CP2104"])[:CommandRx]
    Uart.CommandRx.start_link(config)
    config = Configuration.FixedWing.Cessna2m.Sim.Command.config()
    Command.RemotePilot.start_link(config[:RemotePilot])
    Command.Commander.start_link(config[:Commander])

    Process.sleep(200_000)
  end
end
