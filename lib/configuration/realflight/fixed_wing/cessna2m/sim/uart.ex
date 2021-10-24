defmodule Configuration.Realflight.FixedWing.Cessna2m.Sim.Uart do
  require Logger

  @spec config() :: list()
  def config() do
    peripherals = ["CommandRx_CP2104"]
    Uart.Utils.config(__MODULE__, peripherals)
  end
end
