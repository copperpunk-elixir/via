defmodule Simulation.Xplane.JoystickUsbTest do
  use ExUnit.Case
  require Logger
  alias ViaUtils, as: VU

  setup do
    full_config = Via.Application.start_test()
    {:ok, full_config}
  end

  test "Publish All Values", full_config do
    config = Configuration.FixedWing.Skyhawk.Sim.Command.config()
    Command.RemotePilot.start_link(config[:RemotePilot])
    Command.Commander.start_link(config[:Commander])
    config = Configuration.FixedWing.Skyhawk.Sim.Control.config()
    Control.Controller.start_link(config[:Controller])

    config = full_config[:Estimation][:Estimator]
    Estimation.Estimator.start_link(config)
    Process.sleep(200)

    config = full_config[:Simulation]
    Simulation.Supervisor.start_link(config)

    config = full_config[:Display]
    Display.Supervisor.start_link(config)
    # TEG.start_link()
    Process.sleep(200_000)
  end
end
