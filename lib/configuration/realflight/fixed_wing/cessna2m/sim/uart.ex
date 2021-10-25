defmodule Configuration.Realflight.FixedWing.Cessna2m.Sim.Uart do
  require Logger

  @spec config() :: list()
  def config() do
    peripherals = [
      "CommandRx_virtual",
      "Gps_virtual",
      "DownwardRange_virtual",
      "Companion_virtual"
    ]

    Uart.Utils.config(__MODULE__, peripherals)
  end
end
