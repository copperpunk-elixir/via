defmodule Control.ContollerComputingAttitudeCmds do
  use ExUnit.Case
  require Logger

  setup do
    full_config = Via.Application.start_test()
    {:ok, full_config}
  end

  test "Compute Commands", full_config do
    # Expects comments from Gps operator
    uart_config = Configuration.FixedWing.RfCessna2m.Sim.Uart.config(["FrskyRx_CP2104", "Companion_Pico", "Gps_u-blox"])
    Logger.debug(inspect(uart_config))
    Uart.CommandRx.start_link(uart_config[:CommandRx])
    Uart.Companion.start_link(uart_config[:Companion])
    Uart.Gps.start_link(uart_config[:Gps])

    config = Configuration.FixedWing.RfCessna2m.Sim.Command.config()
    Command.RemotePilot.start_link(config[:RemotePilot])
    Command.Commander.start_link(config[:Commander])
    config = Configuration.FixedWing.RfCessna2m.Sim.Control.config()
    Control.Controller.start_link(config[:Controller])

    config = full_config[:Estimation][:Estimator]
    Estimation.Estimator.start_link(config)

    Process.sleep(200_000)
  end
end
