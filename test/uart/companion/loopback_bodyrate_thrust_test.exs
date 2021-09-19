defmodule Uart.Companion.LoopbackBodyrateThrust do
  use ExUnit.Case
  require Logger

  setup do
    full_config = Via.Application.start_test()
    {:ok, full_config}
  end

  test "Open Serial Port", full_config do
    # Expects Logger statements from Companion operator process_data_fn
   # Expects comments from Gps operator
    uart_config = Configuration.Realflight.FixedWing.Cessna2m.Sim.Uart.config(["FrskyRx_CP2104", "Companion_Pico", "Gps_u-blox"])
    Logger.debug(inspect(uart_config))
    Uart.CommandRx.start_link(uart_config[:CommandRx])
    companion_config = Keyword.put(uart_config[:Companion], :uart_port, "USB Serial")
    Logger.debug("comp config: #{inspect(companion_config)}")
    Uart.Companion.start_link(companion_config)
    Uart.Gps.start_link(uart_config[:Gps])

    config = Configuration.Realflight.FixedWing.Cessna2m.Sim.Command.config()
    Command.RemotePilot.start_link(config[:RemotePilot])
    Command.Commander.start_link(config[:Commander])
    config = Configuration.Realflight.FixedWing.Cessna2m.Sim.Control.config()
    Control.Controller.start_link(config[:Controller])

    config = full_config[:Estimation][:Estimator]
    Estimation.Estimator.start_link(config)

      Process.sleep(200_000)
      end
end
