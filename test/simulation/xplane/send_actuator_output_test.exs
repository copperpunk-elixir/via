defmodule Simulation.Xplane.SendActuatorOutputTest do
  use ExUnit.Case
  require Logger
  alias ViaUtils, as: VU
  alias TestHelper.Estimation.GenServer, as: TEG

  setup do
    full_config = Via.Application.start_test()
    {:ok, full_config}
  end

  test "Publish All Values", full_config do
    config = Configuration.FixedWing.Cessna2m.Sim.Uart.config(["FrskyRx_CP2104"])[:CommandRx]
    Logger.debug(inspect(config))
    Uart.CommandRx.start_link(config)
    config = Configuration.FixedWing.Cessna2m.Sim.Command.config()
    Command.RemotePilot.start_link(config[:RemotePilot])
    Command.Commander.start_link(config[:Commander])
    config = Configuration.FixedWing.Cessna2m.Sim.Control.config()
    Control.Controller.start_link(config[:Controller])

    config = full_config[:Estimation][:Estimator]
    Estimation.Estimator.start_link(config)
    Process.sleep(200)

    config = full_config[:Simulation]
    Simulation.Supervisor.start_link(config)

    # TEG.start_link()
    Process.sleep(200_000)
  end
end
