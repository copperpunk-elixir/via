defmodule Simulation.Xplane.FrskyXplaneTest do
  use ExUnit.Case
  require Logger
  alias ViaUtils, as: VU

  setup do
    full_config = Via.Application.start_test()
    {:ok, full_config}
  end

  test "Publish All Values", full_config do
    config = Configuration.FixedWing.RfCessna2m.Sim.Command.config()
    Command.RemotePilot.start_link(config[:RemotePilot])
    Command.Commander.start_link(config[:Commander])
    config = Configuration.FixedWing.RfCessna2m.Sim.Control.config()
    Control.Controller.start_link(config[:Controller])

    config = full_config[:Estimation][:Estimator]
    Estimation.Estimator.start_link(config)
    Process.sleep(200)

    config = Configuration.FixedWing.RfCessna2m.Sim.Uart.config(["FrskyRx_CP2104"])
    Uart.CommandRx.start_link(config[:CommandRx])

    config = full_config[:Simulation]
    |> Keyword.drop([:ViaJoystick])
    Simulation.Supervisor.start_link(config)

    config = full_config[:Display]
    Display.Supervisor.start_link(config)
    # TEG.start_link()
    Process.sleep(200_000)
  end
end
