defmodule Control.ContollerReceivingGoalsTest do
  use ExUnit.Case
  require Logger

  setup do
    Via.Application.start_test()
    {:ok, []}
  end

  test "Open Serial Port" do
    # Expects comments from Gps operator
    config = Configuration.RealFlight.FixedWing.Cessna2m.Sim.Uart.config(["FrskyRx_CP2104"])[:CommandRx]
    Logger.debug(inspect(config))
    Uart.CommandRx.start_link(config)
    config = Configuration.RealFlight.FixedWing.Cessna2m.Sim.Command.config()
    Command.RemotePilot.start_link(config[:RemotePilot])
    Command.Commander.start_link(config[:Commander])
    config = Configuration.RealFlight.FixedWing.Cessna2m.Sim.Control.config()
    Control.Controller.start_link(config[:Controller])

    Process.sleep(200_000)
  end
end
